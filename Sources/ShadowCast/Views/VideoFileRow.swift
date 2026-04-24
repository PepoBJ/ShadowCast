import SwiftUI

struct VideoFileRow: View {
    let file: VideoFile
    @Environment(AppViewModel.self) private var appViewModel
    @State private var workStartTime: Date? = nil
    @State private var tickElapsed: TimeInterval = 0
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator bar on left
            Rectangle()
                .frame(width: 2)
                .foregroundStyle(indicatorColor)
                .neonGlow(indicatorColor, radius: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(file.displayName)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    statusBadge
                    Text(file.formattedFileSize)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(CP.dim)
                }
            }
            Spacer()
            trailingContent
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 4)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            let status = appViewModel.transcriptionStatus(for: file)
            switch status {
            case .queued, .remuxing, .inProgress:
                if workStartTime == nil { workStartTime = Date() }
                tickElapsed = Date().timeIntervalSince(workStartTime ?? Date())
            default:
                workStartTime = nil; tickElapsed = 0
            }
        }
        .onChange(of: appViewModel.transcriptionStatus(for: file)) { _, new in
            switch new {
            case .queued, .remuxing, .inProgress:
                if workStartTime == nil { workStartTime = Date() }
            default:
                workStartTime = nil; tickElapsed = 0
            }
        }
    }

    private var indicatorColor: Color {
        if file.isMKV && !file.isReadyForPlayback { return CP.orange }
        switch appViewModel.transcriptionStatus(for: file) {
        case .completed:   return CP.green
        case .inProgress, .remuxing: return CP.yellow
        case .queued:      return CP.cyan.opacity(0.5)
        case .failed:      return CP.red
        default:           return CP.border
        }
    }

    @ViewBuilder
    private var trailingContent: some View {
        let status = appViewModel.transcriptionStatus(for: file)
        switch status {
        case .notTranscribed:
            Button("TRANSCRIBE") { appViewModel.transcribe(file: file) }
                .buttonStyle(CyberpunkButtonStyle(color: CP.cyan))
        case .queued:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small).tint(CP.cyan)
                Text("QUEUED").font(.system(size: 9, design: .monospaced)).foregroundStyle(CP.dim)
            }
        case .remuxing:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small).tint(CP.yellow)
                Text("CONVERTING").font(.system(size: 9, design: .monospaced)).foregroundStyle(CP.yellow)
            }
        case .inProgress(let phase, _, _):
            HStack(spacing: 4) {
                ProgressView().controlSize(.small).tint(CP.magenta)
                VStack(alignment: .leading, spacing: 1) {
                    Text(phase.uppercased().replacingOccurrences(of: "…", with: ""))
                        .font(.system(size: 9, design: .monospaced)).foregroundStyle(CP.magenta)
                    Text(formatElapsed(tickElapsed))
                        .font(.system(size: 9, design: .monospaced)).foregroundStyle(CP.dim)
                        .monospacedDigit()
                }
            }
        case .completed:
            EmptyView()
        case .failed(let msg):
            Button("RETRY") { appViewModel.transcribe(file: file) }
                .buttonStyle(CyberpunkButtonStyle(color: CP.red))
                .help(msg)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if file.isMKV && !file.isReadyForPlayback {
            Text("MKV")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(CP.orange)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .overlay(RoundedRectangle(cornerRadius: 1).stroke(CP.orange, lineWidth: 0.5))
                .help("Will auto-convert via ffmpeg on Transcribe")
        } else {
            let status = appViewModel.transcriptionStatus(for: file)
            switch status {
            case .completed:
                Text("SYNCED")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(CP.green).neonGlow(CP.green, radius: 2)
            case .inProgress, .remuxing:
                Text("PROC")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(CP.yellow).neonGlow(CP.yellow, radius: 2)
            case .queued:
                Text("QUEUE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(CP.cyan.opacity(0.6))
            case .failed:
                Text("ERR")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(CP.red)
            default:
                Text("RAW")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(CP.dimmer)
            }
        }
    }

    private func formatElapsed(_ elapsed: TimeInterval) -> String {
        String(format: "%d:%02d", Int(elapsed)/60, Int(elapsed)%60)
    }
}
