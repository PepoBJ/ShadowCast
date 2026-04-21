import Foundation
import whisper

actor TranscriptionService {
    nonisolated let progressStream: AsyncStream<TranscriptionProgress>
    private let progressContinuation: AsyncStream<TranscriptionProgress>.Continuation

    init() {
        let (stream, continuation) = AsyncStream.makeStream(of: TranscriptionProgress.self, bufferingPolicy: .unbounded)
        self.progressStream = stream
        self.progressContinuation = continuation
    }

    /// Transcribes a video file using the Whisper model at modelPath.
    /// Per D-26: serial by actor isolation (one job at a time).
    /// Per D-28: whisper context created and freed within this call.
    /// - sidecarURL: where to write the .transcript.json — defaults to next to `file.url`.
    ///   Pass the original file's transcriptURL when `file` is a remuxed copy in a temp dir.
    func transcribe(file: VideoFile, modelPath: String, language: String = "auto", sidecarURL: URL? = nil) async throws -> TranscriptDocument {
        progressContinuation.yield(.started(videoID: file.id))
        let startTime = Date()

        do {
            // Step 1: Extract audio
            let samples = try await AudioExtractor.extractPCM(from: file.url)

            // Step 2: Load whisper context (D-19, using non-deprecated API)
            var cparams = whisper_context_default_params()
            cparams.use_gpu = true

            guard let ctx = modelPath.withCString({ path in
                whisper_init_from_file_with_params(path, cparams)
            }) else {
                throw TranscriptionError.modelLoadFailed(path: modelPath)
            }
            defer { whisper_free(ctx) }
            print("[Whisper] Model loaded. Starting transcription of \(samples.count) samples (\(samples.count / 16000)s)…")
            print("[Whisper] This may take 1–5x realtime depending on model size and hardware.")

            // Step 3: Configure whisper params
            var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
            params.n_threads = Int32(min(8, ProcessInfo.processInfo.processorCount))
            params.token_timestamps = true    // CRITICAL: must be explicit or t0/t1 = -1
            params.print_progress = false
            params.print_realtime = false
            params.print_timestamps = false

            // Step 4: Run whisper_full with safe language pointer lifetime
            let langStr: String? = language == "auto" ? nil : language
            let result: Int32 = withOptionalCString(langStr) { langPtr in
                params.language = langPtr
                return samples.withUnsafeBufferPointer { buf in
                    whisper_full(ctx, params, buf.baseAddress, Int32(buf.count))
                }
            }

            print("[Whisper] whisper_full returned: \(result)")
            guard result == 0 else {
                print("[Whisper] ERROR: whisper_full failed with code \(result)")
                throw TranscriptionError.whisperFailed(code: result)
            }

            // Step 5: Extract segments
            let nSegments = Int(whisper_full_n_segments(ctx))
            print("[Whisper] Got \(nSegments) segments")
            var segments: [TranscriptSegment] = []

            for i in 0..<nSegments {
                // D-21: filter hallucinated silence
                let noSpeechProb = whisper_full_get_segment_no_speech_prob(ctx, Int32(i))
                guard noSpeechProb <= 0.6 else { continue }

                // Strip [_BEG_] and [_TT_NNN] tokens from segment text
                let rawSegText = String(cString: whisper_full_get_segment_text(ctx, Int32(i)))
                let segText = cleanSegmentText(rawSegText)
                let segT0 = Double(whisper_full_get_segment_t0(ctx, Int32(i))) / 100.0
                let segT1 = Double(whisper_full_get_segment_t1(ctx, Int32(i))) / 100.0

                // Word-level tokens — use whisper_full_n_tokens (NOT whisper_full_get_segment_n_tokens)
                let nTokens = Int(whisper_full_n_tokens(ctx, Int32(i)))
                var words: [WordTiming] = []

                for j in 0..<nTokens {
                    let td = whisper_full_get_token_data(ctx, Int32(i), Int32(j))
                    let tokenText = String(cString: whisper_full_get_token_text(ctx, Int32(i), Int32(j)))

                    // Skip special tokens: <...> tags, [_BEG_], [_TT_NNN] timestamp tokens
                    guard !tokenText.hasPrefix("<"),
                          !tokenText.hasPrefix("["),
                          td.t0 >= 0, td.t1 >= 0 else { continue }

                    let wordStart = Double(td.t0) / 100.0  // centiseconds → seconds (D-20)
                    let wordEnd = Double(td.t1) / 100.0
                    words.append(WordTiming(word: tokenText, start: wordStart, end: wordEnd, probability: td.p))
                }

                segments.append(TranscriptSegment(id: i, start: segT0, end: segT1, text: segText, words: words))

                // Yield progress
                let elapsed = Date().timeIntervalSince(startTime)
                progressContinuation.yield(.progress(videoID: file.id, segmentsProcessed: segments.count, elapsed: elapsed))
            }

            // Step 6: Build document
            let duration = samples.isEmpty ? 0.0 : Double(samples.count) / 16000.0
            let doc = TranscriptDocument(version: 1, language: language, duration: duration, segments: segments)

            // Step 7: Atomic sidecar write (D-39)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(doc)
            let dest = sidecarURL ?? file.transcriptURL
            let temp = dest.deletingLastPathComponent()
                           .appendingPathComponent(".\(UUID().uuidString).tmp")
            try data.write(to: temp)
            _ = try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: temp, to: dest)

            progressContinuation.yield(.completed(videoID: file.id, transcript: doc))
            return doc

        } catch {
            progressContinuation.yield(.failed(videoID: file.id, errorMessage: error.localizedDescription))
            throw error
        }
    }

    func finish() {
        progressContinuation.finish()
    }
}

/// Remove Whisper special tokens like [_BEG_], [_TT_454] from segment text.
private func cleanSegmentText(_ text: String) -> String {
    // Match [_ANYTHING_] or [_ANYTHING_NNN] patterns
    guard let regex = try? NSRegularExpression(pattern: #"\[_[A-Z_0-9]+\]"#) else { return text }
    let range = NSRange(text.startIndex..., in: text)
    let cleaned = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    return cleaned.trimmingCharacters(in: .whitespaces)
}

// Helper for safe optional C string pointer lifetime
private func withOptionalCString<R>(_ string: String?, body: (UnsafePointer<CChar>?) -> R) -> R {
    if let string {
        return string.withCString { ptr in body(ptr) }
    } else {
        return body(nil)
    }
}
