import Foundation

enum TranscriptionStatus: Sendable, Equatable {
    case notTranscribed
    case queued
    case remuxing
    case inProgress(phase: String, segmentsProcessed: Int, elapsed: TimeInterval)
    case completed
    case failed(String)
}

enum TranscriptionProgress: Sendable {
    case started(videoID: UUID)
    case progress(videoID: UUID, segmentsProcessed: Int, elapsed: TimeInterval)
    case completed(videoID: UUID, transcript: TranscriptDocument)
    case failed(videoID: UUID, errorMessage: String)
}

struct TranscriptionJob: Sendable {
    let videoID: UUID
    var status: TranscriptionStatus
}

enum TranscriptionError: Error, Sendable {
    case modelLoadFailed(path: String)
    case whisperFailed(code: Int32)
    case noAudioTrack
}

enum AudioExtractionError: Error, Sendable {
    case noAudioTrack
    case cannotAddOutput
    case readerFailed(String)
}
