import AVFoundation

enum AudioExtractor {
    /// Extracts 16kHz mono Float32 PCM samples from a video file (per D-23, D-24).
    static func extractPCM(from videoURL: URL) async throws -> [Float] {
        print("[AudioExtractor] Loading asset: \(videoURL.lastPathComponent)")
        let asset = AVURLAsset(url: videoURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        print("[AudioExtractor] Found \(audioTracks.count) audio track(s)")
        guard !audioTracks.isEmpty else { throw AudioExtractionError.noAudioTrack }

        let reader = try AVAssetReader(asset: asset)

        let outputSettings: [String: Any] = [
            AVFormatIDKey:               kAudioFormatLinearPCM,
            AVSampleRateKey:             16000,
            AVNumberOfChannelsKey:       1,
            AVLinearPCMBitDepthKey:      32,
            AVLinearPCMIsFloatKey:       true,
            AVLinearPCMIsBigEndianKey:   false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let output = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: outputSettings)
        output.alwaysCopiesSampleData = false

        guard reader.canAdd(output) else { throw AudioExtractionError.cannotAddOutput }
        reader.add(output)
        reader.startReading()
        print("[AudioExtractor] Reading PCM samples…")

        var samples: [Float] = []
        samples.reserveCapacity(16000 * 3600)

        while reader.status == .reading {
            guard let sampleBuffer = output.copyNextSampleBuffer() else { break }
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }
            let dataLength = CMBlockBufferGetDataLength(blockBuffer)
            let frameCount = dataLength / MemoryLayout<Float>.stride
            let chunk = [Float](unsafeUninitializedCapacity: frameCount) { buf, count in
                CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: dataLength, destination: buf.baseAddress!)
                count = frameCount
            }
            samples.append(contentsOf: chunk)
        }

        print("[AudioExtractor] Done. \(samples.count) samples (~\(samples.count / 16000)s of audio)")
        if reader.status == .failed {
            print("[AudioExtractor] Reader failed: \(reader.error?.localizedDescription ?? "unknown")")
            throw AudioExtractionError.readerFailed(reader.error?.localizedDescription ?? "unknown")
        }

        // D-24: warn for very large files
        if samples.count * MemoryLayout<Float>.stride > 500_000_000 {
            print("AudioExtractor: large audio buffer (\(samples.count * 4 / 1_000_000)MB) — chunked streaming not yet implemented")
        }

        return samples
    }
}
