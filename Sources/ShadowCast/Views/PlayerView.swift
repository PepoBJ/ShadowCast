import SwiftUI
import AppKit

struct PlayerView: View {
    @Bindable var viewModel: PlayerViewModel
    @Environment(AppViewModel.self) private var appViewModel

    @State private var keyMonitor: Any?

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Video: 75% of height
                AVPlayerWrapper(player: viewModel.player)
                    .frame(height: geo.size.height * 0.75)

                Divider()

                // Transcript strip: 25% of height
                Group {
                    if let transcript = viewModel.transcript {
                        TranscriptView(
                            transcript: transcript,
                            currentWordIndex: viewModel.currentWordIndex,
                            onWordTap: { time in viewModel.seek(to: time) }
                        )
                        .contextMenu {
                            Button("Copy All Text") {
                                let text = transcript.segments.map(\.text).joined(separator: "\n")
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(text, forType: .string)
                            }
                        }
                    } else {
                        TranscriptStatusView()
                    }
                }
                .id(viewModel.transcript == nil)
                .frame(height: geo.size.height * 0.25)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .overlay {
            Button("") { viewModel.togglePlayPause() }
                .keyboardShortcut(" ", modifiers: [])
                .frame(width: 0, height: 0)
                .opacity(0)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // Use a string-keyed binding to avoid Float precision issues
                Picker("Speed", selection: Binding(
                    get: { speedLabel(viewModel.playbackRate) },
                    set: { label in
                        if let rate = speedValue(label) {
                            viewModel.setPlaybackRate(rate)
                        }
                    }
                )) {
                    ForEach(speedOptions, id: \.self) { label in
                        Text(label).tag(label)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 72)
            }
        }
        .onAppear {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [viewModel] event in
                switch event.keyCode {
                case 123: viewModel.seekRelative(by: -5); return nil
                case 124: viewModel.seekRelative(by: 5); return nil
                default: return event
                }
            }
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
    }

    private let speedOptions = ["0.5×", "0.75×", "1×", "1.25×", "1.5×"]

    private func speedLabel(_ rate: Float) -> String {
        switch rate {
        case 0.5:  return "0.5×"
        case 0.75: return "0.75×"
        case 1.25: return "1.25×"
        case 1.5:  return "1.5×"
        default:   return "1×"
        }
    }

    private func speedValue(_ label: String) -> Float? {
        switch label {
        case "0.5×":  return 0.5
        case "0.75×": return 0.75
        case "1×":    return 1.0
        case "1.25×": return 1.25
        case "1.5×":  return 1.5
        default:      return nil
        }
    }
}
