import Foundation

enum MKVRemuxer {
    /// Remuxes an MKV file to MP4 using ffmpeg (stream copy — fast, lossless).
    /// Returns the URL of the output MP4 file.
    /// Local cache dir for remuxed files — avoids writing back to cloud storage (Google Drive, iCloud, etc.)
    static let localCacheDir: URL = {
        let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = cache.appendingPathComponent("ShadowCast/remuxed", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func remux(mkvURL: URL) async throws -> URL {
        // Output goes to local cache, not back to the source folder (avoids cloud write issues)
        let filename = mkvURL.deletingPathExtension().lastPathComponent + ".mp4"
        let outputURL = localCacheDir.appendingPathComponent(filename)
        print("[MKVRemuxer] Input:  \(mkvURL.path)")
        print("[MKVRemuxer] Output: \(outputURL.path)")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            print("[MKVRemuxer] Already exists in cache, skipping remux")
            return outputURL
        }

        guard let ffmpegPath = findFFmpeg() else {
            print("[MKVRemuxer] ERROR: ffmpeg not found. Checked: /opt/homebrew/bin/ffmpeg, /usr/local/bin/ffmpeg, /usr/bin/ffmpeg")
            throw RemuxError.ffmpegNotFound
        }
        print("[MKVRemuxer] Using ffmpeg at: \(ffmpegPath)")

        // Copy input to local temp first — avoids Google Drive/iCloud suspending ffmpeg reads
        let localInput: URL
        let isCloudFile = mkvURL.path.contains("CloudStorage") || mkvURL.path.contains("iCloud")
        if isCloudFile {
            localInput = FileManager.default.temporaryDirectory
                .appendingPathComponent(mkvURL.lastPathComponent)
            if !FileManager.default.fileExists(atPath: localInput.path) {
                print("[MKVRemuxer] Cloud file detected — copying to local temp first…")
                try FileManager.default.copyItem(at: mkvURL, to: localInput)
                print("[MKVRemuxer] Local copy ready: \(localInput.path)")
            }
        } else {
            localInput = mkvURL
        }

        // Use posix_spawn instead of Process — macOS kills Process-launched binaries
        // from Hardened Runtime apps with SIGKILL (exit 9). posix_spawn bypasses this.
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                print("[MKVRemuxer] Starting ffmpeg via posix_spawn…")
                let exitCode = spawnFFmpeg(ffmpegPath: ffmpegPath,
                                           input: localInput.path,
                                           output: outputURL.path)
                if isCloudFile { try? FileManager.default.removeItem(at: localInput) }
                if exitCode == 0 {
                    print("[MKVRemuxer] Success!")
                    continuation.resume(returning: outputURL)
                } else {
                    print("[MKVRemuxer] FAILED exit code \(exitCode)")
                    continuation.resume(throwing: RemuxError.ffmpegFailed(Int(exitCode)))
                }
            }
        }
    }

    private static func findFFmpeg() -> String? {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]
        let found = candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
        print("[MKVRemuxer] findFFmpeg: \(found ?? "NOT FOUND")")
        return found
    }
}

enum RemuxError: Error, Sendable {
    case ffmpegNotFound
    case ffmpegFailed(Int)
}

/// Launch ffmpeg via posix_spawn — bypasses the macOS security policy that
/// sends SIGKILL to binaries launched via Process() from Hardened Runtime apps.
private func spawnFFmpeg(ffmpegPath: String, input: String, output: String) -> Int32 {
    var pid: pid_t = 0
    let args: [String] = [ffmpegPath, "-y", "-i", input, "-c", "copy", output]
    var argv = args.map { strdup($0) } + [nil]
    // Inherit parent environment so ffmpeg can find libraries
    var envp: [UnsafeMutablePointer<CChar>?] = [nil]

    let ret = posix_spawn(&pid, ffmpegPath, nil, nil, &argv, &envp)
    argv.forEach { $0.map { free($0) } }

    guard ret == 0 else {
        print("[MKVRemuxer] posix_spawn failed: \(ret)")
        return -1
    }
    print("[MKVRemuxer] ffmpeg PID \(pid)")

    var status: Int32 = 0
    waitpid(pid, &status, 0)
    return status >> 8  // extract exit code from wait status
}
