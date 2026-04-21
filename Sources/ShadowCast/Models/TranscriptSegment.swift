import Foundation

struct TranscriptSegment: Codable, Identifiable {
    let id: Int
    let start: Double
    let end: Double
    let text: String
    let words: [WordTiming]
}
