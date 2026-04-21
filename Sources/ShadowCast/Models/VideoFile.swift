import Foundation

struct VideoFile: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let fileSize: Int64
    let dateModified: Date

    /// Stable ID derived from the file path — survives re-enumeration so transcription
    /// job state keyed by id remains valid after videoFiles is refreshed.
    init(url: URL, fileSize: Int64, dateModified: Date) {
        self.id = UUID(uuidString: url.path.uuidStringFromPath) ?? UUID()
        self.url = url
        self.fileSize = fileSize
        self.dateModified = dateModified
    }

    /// Explicit ID override — used when creating a synthetic VideoFile pointing at a
    /// remuxed MP4 that should share the same job identity as the original MKV.
    init(id: UUID, url: URL, fileSize: Int64, dateModified: Date) {
        self.id = id
        self.url = url
        self.fileSize = fileSize
        self.dateModified = dateModified
    }

    var displayName: String { url.deletingPathExtension().lastPathComponent }
    var fileExtension: String { url.pathExtension.lowercased() }

    var isMKV: Bool { fileExtension == "mkv" }

    /// For MKV files, returns the remuxed MP4 URL from local cache if it exists.
    var playbackURL: URL {
        guard isMKV else { return url }
        let cached = MKVRemuxer.localCacheDir
            .appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".mp4")
        return FileManager.default.fileExists(atPath: cached.path) ? cached : url
    }

    /// True if the remuxed MP4 exists in local cache (for MKV) or the file is directly playable.
    var isReadyForPlayback: Bool {
        if isMKV {
            let cached = MKVRemuxer.localCacheDir
                .appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".mp4")
            return FileManager.default.fileExists(atPath: cached.path)
        }
        return true
    }

    var transcriptURL: URL {
        url.deletingPathExtension().appendingPathExtension("transcript.json")
    }

    var hasTranscript: Bool {
        FileManager.default.fileExists(atPath: transcriptURL.path)
    }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    static let supportedExtensions: Set<String> = ["mp4", "mov", "mkv"]
}

private extension String {
    /// Deterministic UUID-format string from a file path using a simple hash.
    /// Allows VideoFile.id to be stable across re-enumerations.
    var uuidStringFromPath: String {
        var hash = UInt64(14695981039346656037)
        for byte in self.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        let h = hash
        // All masks applied at UInt64 level before formatting to avoid overflow
        return String(format: "%08X-%04X-%04X-%04X-%012X",
            UInt32(h >> 32),
            (h >> 16) & 0xFFFF,
            (h & 0x0FFF) | 0x4000,
            ((h >> 8) & 0x3FFF) | 0x8000,
            h & 0xFFFFFFFFFFFF)
    }
}
