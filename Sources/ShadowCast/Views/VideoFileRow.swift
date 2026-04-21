import SwiftUI

struct VideoFileRow: View {
    let file: VideoFile
    @Environment(AppViewModel.self) private var appViewModel
    @State private var workStartTime: Date? = nil
    @State private var tickElapsed: TimeInterval = 0

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayName)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    statusBadge
                    Text(file.formattedFileSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            trailingContent
        }
        .padding(.vertical, 2)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            let status = appViewModel.transcriptionStatus(for: file)
            switch status {
            case .queued, .remuxing, .inProgress:
                if workStartTime == nil { workStartTime = Date() }
                tickElapsed = Date().timeIntervalSince(workStartTime ?? Date())
            default:
                workStartTime = nil
                tickElapsed = 0
            }
        }
        .onChange(of: appViewModel.transcriptionStatus(for: file)) { _, new in
            switch new {
            case .queued, .remuxing, .inProgress:
                if workStartTime == nil { workStartTime = Date() }
            default:
                workStartTime = nil
                tickElapsed = 0
            }
        }
    }

    @ViewBuilder
    private var trailingContent: some View {
        let status = appViewModel.transcriptionStatus(for: file)
        switch status {
        case .notTranscribed:
            Button("Transcribe") {
                appViewModel.transcribe(file: file)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        case .queued:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("Queued").font(.caption).foregroundStyle(.secondary)
            }
        case .remuxing:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("Converting…").font(.caption).foregroundStyle(.secondary)
            }
            .onAppear { if workStartTime == nil { workStartTime = Date() } }
        case .inProgress(let phase, _, _):
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                VStack(alignment: .leading, spacing: 1) {
                    Text(phase)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formatElapsed(tickElapsed))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .onAppear { if workStartTime == nil { workStartTime = Date() } }
        case .completed:
            EmptyView()
        case .failed(let msg):
            Button("Retry") {
                appViewModel.transcribe(file: file)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(msg)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if file.isMKV && !file.isReadyForPlayback {
            // MKV not yet remuxed — will be remuxed on Transcribe
            Label("MKV", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption2)
                .foregroundStyle(.orange)
                .help("Clicking Transcribe will convert this MKV to MP4 automatically using ffmpeg.")
        } else {
            let status = appViewModel.transcriptionStatus(for: file)
            switch status {
            case .completed:
                Label("Transcribed", systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            case .remuxing:
                Label("Converting", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            case .inProgress(let phase, _, _):
                Label(phase == "Transcribing…" ? "Transcribing" : "Working",
                      systemImage: "waveform")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            case .queued:
                Label("Queued", systemImage: "clock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            case .failed:
                Label("Failed", systemImage: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
            default:
                Label("No transcript", systemImage: "doc.text")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formatElapsed(_ elapsed: TimeInterval) -> String {
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
