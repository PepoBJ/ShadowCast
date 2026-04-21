import Foundation

/// Watches a directory for file system changes using DispatchSource (per D-15).
/// Provides file-settling debounce for incrementally-written files like OBS recordings (per D-16).
@MainActor
final class FolderWatchManager {
    private var source: DispatchSourceFileSystemObject?
    private var watchedFolderFD: Int32 = -1
    private var onChange: (@Sendable () -> Void)?
    private var settlingTasks: [URL: Task<Void, Never>] = [:]

    func startWatching(url: URL, onChange: @escaping @Sendable () -> Void) {
        stopWatching()
        self.onChange = onChange

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            print("FolderWatchManager: failed to open \(url.path) (errno: \(errno))")
            return
        }
        watchedFolderFD = fd

        // Use .main queue so the event handler runs on MainActor directly.
        // Swift 6: closures capturing @MainActor self require the handler to run on main queue.
        // Running on a background queue causes _dispatch_assert_queue_fail crash.
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: DispatchQueue.main
        )

        src.setEventHandler { [weak self] in
            self?.handleDirectoryEvent()
        }

        src.setCancelHandler {
            close(fd)
        }

        src.resume()
        self.source = src
    }

    func stopWatching() {
        for (_, task) in settlingTasks { task.cancel() }
        settlingTasks.removeAll()
        source?.cancel()
        source = nil
        watchedFolderFD = -1
        onChange = nil
    }

    // MARK: - File Settling Debounce (D-16)

    nonisolated func waitForFileToSettle(url: URL) async -> Bool {
        var lastSize: Int = -1
        var stableCount = 0
        while stableCount < 3 {
            guard !Task.isCancelled else { return false }
            try? await Task.sleep(for: .seconds(1))
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let size = attrs[.size] as? Int else { return false }
            if size == lastSize && size > 0 {
                stableCount += 1
            } else {
                stableCount = 0
                lastSize = size
            }
        }
        return true
    }

    private func handleDirectoryEvent() {
        onChange?()
    }

    deinit {
        source?.cancel()
    }
}
