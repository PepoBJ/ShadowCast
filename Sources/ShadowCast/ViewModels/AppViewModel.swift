import Observation
import Foundation
import AppKit

/// Root state owner for the app. Injected via .environment() at the WindowGroup level.
/// Per D-17: uses @Observable (not ObservableObject), strict concurrency, @MainActor.
@Observable
@MainActor
final class AppViewModel {
    var watchedFolderURL: URL? = nil
    var videoFiles: [VideoFile] = []
    var selectedVideoID: VideoFile.ID? = nil

    private let folderWatchManager = FolderWatchManager()

    // MARK: - Transcription State (D-34)
    var transcriptionJobs: [UUID: TranscriptionJob] = [:]
    var isDownloadingModel: Bool = false
    var modelDownloadProgress: Double = 0.0

    // MARK: - Model Selection (D-32)
    // Stored so @Observable tracks changes and SwiftUI re-renders the picker immediately.
    var selectedModelSize: WhisperModelSize = ModelManager.selectedModelSize {
        didSet { ModelManager.selectedModelSize = selectedModelSize }
    }

    private let transcriptionService = TranscriptionService()
    private let modelManager = ModelManager()
    private var progressListenerTask: Task<Void, Never>?
    private var downloadProgressListenerTask: Task<Void, Never>?
    private var isListeningToProgress = false

    // MARK: - Player State (D-68)
    var playerViewModel: PlayerViewModel? = nil

    func selectVideo(id: VideoFile.ID?) {
        playerViewModel = nil
        guard let id,
              let file = videoFiles.first(where: { $0.id == id }) else { return }

        if file.isMKV && !file.isReadyForPlayback {
            // MKV not yet converted — detail pane shows "Convert & Play" button, don't auto-remux
            return
        } else if file.isMKV {
            // Already remuxed — play from cache MP4 but load transcript from original location
            let playbackFile = VideoFile(id: file.id, url: file.playbackURL,
                                         fileSize: file.fileSize, dateModified: file.dateModified)
            playerViewModel = PlayerViewModel(file: playbackFile, transcriptURL: file.transcriptURL)
        } else {
            playerViewModel = PlayerViewModel(file: file)
        }
    }

    /// Explicitly convert an MKV to MP4 then open it in the player.
    /// Called by the "Convert & Play" button in the detail pane.
    func convertAndPlay(file: VideoFile) {
        guard file.isMKV else { return }
        Task {
            do {
                print("[ConvertAndPlay] Remuxing \(file.displayName)…")
                let mp4URL = try await MKVRemuxer.remux(mkvURL: file.url)
                if let url = watchedFolderURL { videoFiles = enumerateVideoFiles(in: url) }
                let playbackFile = VideoFile(id: file.id, url: mp4URL,
                                             fileSize: file.fileSize, dateModified: file.dateModified)
                playerViewModel = PlayerViewModel(file: playbackFile, transcriptURL: file.transcriptURL)
                print("[ConvertAndPlay] Done, playing \(mp4URL.lastPathComponent)")
            } catch {
                print("[ConvertAndPlay] Failed: \(error)")
            }
        }
    }

    // MARK: - Folder Selection (FOLD-01)

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        panel.message = "Select a folder containing video files to watch"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        setWatchedFolder(url)
    }

    func setWatchedFolder(_ url: URL) {
        if watchedFolderURL != nil {
            folderWatchManager.stopWatching()
            watchedFolderURL?.stopAccessingSecurityScopedResource()
        }
        watchedFolderURL = url
        persistFolderPath(url: url)
        videoFiles = enumerateVideoFiles(in: url)
        folderWatchManager.startWatching(url: url) { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleDirectoryChange()
            }
        }
        ensureProgressListening()
    }

    // MARK: - Folder Persistence (FOLD-02)
    // Non-sandboxed app — plain path string is sufficient, no security-scoped bookmarks needed.

    private func persistFolderPath(url: URL) {
        UserDefaults.standard.set(url.path, forKey: "watchedFolderPath")
    }

    func saveCurrentFolderBookmark() {
        guard let url = watchedFolderURL else { return }
        persistFolderPath(url: url)
    }

    func restorePersistedFolder() {
        guard let path = UserDefaults.standard.string(forKey: "watchedFolderPath") else { return }
        let url = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            UserDefaults.standard.removeObject(forKey: "watchedFolderPath")
            return
        }
        setWatchedFolder(url)
    }

    // MARK: - File Enumeration (FOLD-03, FOLD-04)

    private func enumerateVideoFiles(in folderURL: URL) -> [VideoFile] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents.compactMap { fileURL -> VideoFile? in
            let ext = fileURL.pathExtension.lowercased()
            guard VideoFile.supportedExtensions.contains(ext) else { return nil }
            let rv = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            return VideoFile(
                url: fileURL,
                fileSize: Int64(rv?.fileSize ?? 0),
                dateModified: rv?.contentModificationDate ?? Date()
            )
        }
        .sorted { $0.dateModified > $1.dateModified }
    }

    private func handleDirectoryChange() {
        guard let url = watchedFolderURL else { return }
        videoFiles = enumerateVideoFiles(in: url)
    }

    func stopWatching() {
        progressListenerTask?.cancel()
        downloadProgressListenerTask?.cancel()
        folderWatchManager.stopWatching()
    }

    // MARK: - Transcription Orchestration (TRNS-01)

    func transcribe(file: VideoFile) {
        // Block if already running or done
        switch transcriptionJobs[file.id]?.status {
        case .queued, .remuxing, .inProgress: return
        case .completed: return
        default: break
        }
        transcriptionJobs[file.id] = TranscriptionJob(videoID: file.id, status: .queued)

        Task {
            do {
                var transcribeFile = file
                print("[Transcribe] Starting job for: \(file.displayName) (isMKV: \(file.isMKV))")

                // Phase 1: remux MKV → MP4
                if file.isMKV {
                    print("[Transcribe] Phase 1: remuxing MKV → MP4")
                    transcriptionJobs[file.id]?.status = .remuxing
                    let mp4URL = try await MKVRemuxer.remux(mkvURL: file.url)
                    print("[Transcribe] Phase 1 done: \(mp4URL.path)")
                    transcribeFile = VideoFile(id: file.id, url: mp4URL,
                                               fileSize: file.fileSize, dateModified: file.dateModified)
                    if let url = watchedFolderURL { videoFiles = enumerateVideoFiles(in: url) }
                }

                // Phase 2: download model if needed
                print("[Transcribe] Phase 2: ensuring model (\(selectedModelSize.rawValue)) available")
                transcriptionJobs[file.id]?.status = .inProgress(phase: "Downloading model…", segmentsProcessed: 0, elapsed: 0)
                isDownloadingModel = true
                let modelPath = try await modelManager.ensureModelAvailable(selectedModelSize)
                isDownloadingModel = false
                modelDownloadProgress = 0.0
                print("[Transcribe] Phase 2 done: model at \(modelPath)")

                // Phase 3: extract audio + run whisper
                // sidecarURL always points to the ORIGINAL file location, not the remuxed cache copy
                let sidecarURL = file.transcriptURL
                print("[Transcribe] Phase 3: transcribing \(transcribeFile.url.path)")
                print("[Transcribe] Transcript will be saved to: \(sidecarURL.path)")
                transcriptionJobs[file.id]?.status = .inProgress(phase: "Extracting audio…", segmentsProcessed: 0, elapsed: 0)
                _ = try await transcriptionService.transcribe(file: transcribeFile, modelPath: modelPath, sidecarURL: sidecarURL)
                print("[Transcribe] Phase 3 done: transcript written to \(transcribeFile.transcriptURL.path)")

                if let url = watchedFolderURL { videoFiles = enumerateVideoFiles(in: url) }
            } catch {
                print("[Transcribe] ERROR: \(error)")
                transcriptionJobs[file.id]?.status = .failed(error.localizedDescription)
                isDownloadingModel = false
            }
        }
    }

    func transcriptionStatus(for file: VideoFile) -> TranscriptionStatus {
        if file.hasTranscript { return .completed }
        return transcriptionJobs[file.id]?.status ?? .notTranscribed
    }

    // MARK: - Progress Listening

    private func ensureProgressListening() {
        guard !isListeningToProgress else { return }
        isListeningToProgress = true
        startListeningToProgress()
    }

    private func startListeningToProgress() {
        progressListenerTask = Task { [weak self] in
            guard let self else { return }
            for await event in self.transcriptionService.progressStream {
                self.handleTranscriptionProgress(event)
            }
        }
        downloadProgressListenerTask = Task { [weak self] in
            guard let self else { return }
            for await progress in self.modelManager.downloadProgressStream {
                self.modelDownloadProgress = progress
            }
        }
    }

    private func handleTranscriptionProgress(_ event: TranscriptionProgress) {
        switch event {
        case .started(let videoID):
            transcriptionJobs[videoID]?.status = .inProgress(phase: "Transcribing…", segmentsProcessed: 0, elapsed: 0)
        case .progress(let videoID, let segments, let elapsed):
            transcriptionJobs[videoID]?.status = .inProgress(phase: "Transcribing…", segmentsProcessed: segments, elapsed: elapsed)
        case .completed(let videoID, _):
            transcriptionJobs[videoID]?.status = .completed
            if let url = watchedFolderURL {
                videoFiles = enumerateVideoFiles(in: url)
            }
            // If the completed video is currently open in the player, reload the
            // transcript in-place — avoids tearing down AVPlayer (which causes overlap/flicker).
            if selectedVideoID == videoID,
               let file = videoFiles.first(where: { $0.id == videoID }) {
                playerViewModel?.reloadTranscript(from: file.transcriptURL)
            }
        case .failed(let videoID, let msg):
            transcriptionJobs[videoID]?.status = .failed(msg)
        }
    }
}
