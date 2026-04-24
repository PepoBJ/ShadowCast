import SwiftUI

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
        ZStack {
            CP.bg
            VStack(spacing: 14) {
                switch status {
                case .remuxing:
                    cpSpinner(color: CP.yellow)
                    cpLabel("CONVERTING MKV → MP4", color: CP.yellow)
                    cpSub("stream copy · lossless · fast")
                    cpTimer(elapsed)

                case .inProgress(let phase, let segments, _):
                    cpSpinner(color: CP.magenta)
                    cpLabel(phase.uppercased().replacingOccurrences(of: "…", with: ""), color: CP.magenta)
                    if segments > 0 {
                        cpSub("\(segments) SEGMENTS DECODED")
                    }
                    cpTimer(elapsed)

                case .queued:
                    Text("⏳").font(.system(size: 28)).foregroundStyle(CP.cyan)
                    cpLabel("QUEUED", color: CP.cyan)

                case .failed(let msg):
                    Text("⚠").font(.system(size: 28)).foregroundStyle(CP.red).neonGlow(CP.red)
                    cpLabel("PROCESS FAILED", color: CP.red)
                    Text(msg)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(CP.dim)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    if let file = selectedFile {
                        Button("RETRY") { appViewModel.transcribe(file: file) }
                            .buttonStyle(CyberpunkButtonStyle(color: CP.red))
                    }

                default:
                    Text("◈")
                        .font(.system(size: 32, design: .monospaced))
                        .foregroundStyle(CP.border)
                    cpLabel("NO TRANSCRIPT", color: CP.dim)
                    if let file = selectedFile, !file.isMKV || file.isReadyForPlayback {
                        Button("TRANSCRIBE") { appViewModel.transcribe(file: file) }
                            .buttonStyle(CyberpunkButtonStyle(color: CP.cyan))
                    }
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

    @ViewBuilder
    private func cpSpinner(color: Color) -> some View {
        ProgressView()
            .tint(color)
            .scaleEffect(1.2)
    }

    @ViewBuilder
    private func cpLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .neonGlow(color, radius: 3)
            .tracking(2)
    }

    @ViewBuilder
    private func cpSub(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(CP.dim)
    }

    @ViewBuilder
    private func cpTimer(_ t: TimeInterval) -> some View {
        Text(String(format: "%d:%02d", Int(t)/60, Int(t)%60))
            .font(.system(size: 18, weight: .light, design: .monospaced))
            .foregroundStyle(CP.dimmer)
            .monospacedDigit()
    }
}
