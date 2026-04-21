import Foundation

struct TranscriptDocument: Codable {
    let version: Int
    let language: String
    let duration: Double
    let segments: [TranscriptSegment]

    var allWords: [WordTiming] { segments.flatMap(\.words) }
}

extension TranscriptDocument {
    /// Binary search for the word active at `time` (seconds). Uses ±150ms tolerance (SYNC-04).
    /// Takes a pre-cached words array to avoid recomputing allWords each tick.
    func wordIndex(at time: Double, in words: [WordTiming]) -> Int? {
        guard !words.isEmpty else { return nil }
        var lo = 0, hi = words.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if words[mid].end + 0.15 < time {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        guard lo < words.count,
              words[lo].start - 0.15 <= time,
              words[lo].end + 0.15 >= time else { return nil }
        return lo
    }
}
