import Foundation

enum WhisperModelSize: String, CaseIterable, Sendable {
    case base = "base"
    case small = "small"
    case medium = "medium"

    var displayName: String {
        switch self {
        case .base: "Base (~75 MB)"
        case .small: "Small (~500 MB)"
        case .medium: "Medium (~1.5 GB)"
        }
    }

    var filename: String { "ggml-\(rawValue).bin" }

    var downloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-\(rawValue).bin")!
    }
}

enum ModelError: Error, Sendable {
    case downloadFailed(String)
    case invalidURL
    case fileMoveFailed(String)
}

actor ModelManager {
    nonisolated let downloadProgressStream: AsyncStream<Double>
    private let downloadProgressContinuation: AsyncStream<Double>.Continuation

    init() {
        let (stream, continuation) = AsyncStream.makeStream(of: Double.self, bufferingPolicy: .unbounded)
        self.downloadProgressStream = stream
        self.downloadProgressContinuation = continuation
    }

    func modelsDirectory() throws -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ShadowCast/models", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func modelPath(for size: WhisperModelSize) throws -> URL {
        try modelsDirectory().appendingPathComponent(size.filename)
    }

    func isModelDownloaded(_ size: WhisperModelSize) -> Bool {
        guard let path = try? modelPath(for: size) else { return false }
        return FileManager.default.fileExists(atPath: path.path)
    }

    func ensureModelAvailable(_ size: WhisperModelSize) async throws -> String {
        if isModelDownloaded(size) {
            return try modelPath(for: size).path
        }
        let url = try await downloadModel(size)
        return url.path
    }

    func downloadModel(_ size: WhisperModelSize) async throws -> URL {
        let destURL = try modelPath(for: size)
        let continuation = downloadProgressContinuation

        return try await withCheckedThrowingContinuation { cont in
            let delegate = DownloadDelegate(
                progressHandler: { progress in
                    continuation.yield(progress)
                },
                completionHandler: { tempURL, error in
                    if let error {
                        cont.resume(throwing: ModelError.downloadFailed(error.localizedDescription))
                        return
                    }
                    guard let tempURL else {
                        cont.resume(throwing: ModelError.downloadFailed("no temp file"))
                        return
                    }
                    do {
                        if FileManager.default.fileExists(atPath: destURL.path) {
                            try FileManager.default.removeItem(at: destURL)
                        }
                        try FileManager.default.moveItem(at: tempURL, to: destURL)
                        cont.resume(returning: destURL)
                    } catch {
                        cont.resume(throwing: ModelError.fileMoveFailed(error.localizedDescription))
                    }
                }
            )
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            session.downloadTask(with: size.downloadURL).resume()
        }
    }

    private func removeQuarantine(at url: URL) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        task.arguments = ["-d", "com.apple.quarantine", url.path]
        try? task.run()
        task.waitUntilExit()
    }

    // MARK: - Model Selection (D-32)

    nonisolated static var selectedModelSize: WhisperModelSize {
        get {
            let raw = UserDefaults.standard.string(forKey: "selectedWhisperModel") ?? "base"
            return WhisperModelSize(rawValue: raw) ?? .base
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "selectedWhisperModel")
        }
    }
}

// MARK: - URLSessionDownloadDelegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let progressHandler: (Double) -> Void
    let completionHandler: (URL?, Error?) -> Void

    init(progressHandler: @escaping (Double) -> Void, completionHandler: @escaping (URL?, Error?) -> Void) {
        self.progressHandler = progressHandler
        self.completionHandler = completionHandler
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        progressHandler(progress)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        completionHandler(location, nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            completionHandler(nil, error)
        }
    }
}
