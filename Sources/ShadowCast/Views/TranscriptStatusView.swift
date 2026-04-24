import SwiftUI

/// Shown in the transcript pane when no transcript is loaded.
/// Displays live transcription progress if a job is running for the selected video.
struct TranscriptStatusView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var elapsed: TimeInterval = 0
    @State private var startTime: Date? = nil

    private var selectedFile: VideoFile? {
        guard let id = appViewModel.selectedVideoID else { return nil }
        return appViewModel.videoFiles.first(where: { $0.id == id })
    }

    private var status: TranscriptionStatus? {
        guard let file = selectedFile else { return nil }
        return appViewModel.transcriptionJobs[file.id]?.status
    }

    var body: some View {
        VStack(spacing: 16) {
            switch status {
            case .remuxing:
                ProgressView()
                Text("Converting MKV to MP4…")
                    .font(.headline)
                Text("Stream copy — fast, lossless")
                    .font(.caption).foregroundStyle(.secondary)
                Text(formatElapsed(elapsed)).monospacedDigit()
                    .font(.caption).foregroundStyle(.tertiary)

            case .inProgress(let phase, let segments, _):
                ProgressView()
                Text(phase)
                    .font(.headline)
                if segments > 0 {
                    Text("\(segments) segments processed")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(formatElapsed(elapsed)).monospacedDigit()
                    .font(.caption).foregroundStyle(.tertiary)

            case .queued:
                Image(systemName: "clock")
                    .font(.system(size: 32)).foregroundStyle(.secondary)
                Text("Queued for transcription")
                    .font(.headline)

            case .failed(let msg):
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32)).foregroundStyle(.red)
                Text("Transcription failed")
                    .font(.headline)
                Text(msg)
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if let file = selectedFile {
                    Button("Retry") { appViewModel.transcribe(file: file) }
                        .buttonStyle(.borderedProminent)
                }

            default:
                Image(systemName: "text.alignleft")
                    .font(.system(size: 32)).foregroundStyle(.secondary)
                Text("No transcript")
                    .font(.headline)
                if let file = selectedFile, !file.isMKV || file.isReadyForPlayback {
                    Button("Transcribe") { appViewModel.transcribe(file: file) }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard case .remuxing = status ?? .notTranscribed else {
                if case .inProgress = status ?? .notTranscribed {
                    if startTime == nil { startTime = Date() }
                    elapsed = Date().timeIntervalSince(startTime ?? Date())
                    return
                }
                return
            }
            if startTime == nil { startTime = Date() }
            elapsed = Date().timeIntervalSince(startTime ?? Date())
        }
        .onChange(of: status ?? .notTranscribed) { _, new in
            switch new {
            case .remuxing, .inProgress, .queued:
                if startTime == nil { startTime = Date() }
            default:
                startTime = nil; elapsed = 0
            }
        }
    }

    private func formatElapsed(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t)/60, Int(t)%60)
    }
}
