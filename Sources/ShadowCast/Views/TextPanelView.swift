import SwiftUI
import AppKit

struct TextPanelView: View {
    let transcript: TranscriptDocument

    private var fullText: String {
        transcript.segments.map(\.text).joined(separator: " ")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Transcript Text")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Copy All") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(fullText, forType: .string)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                Text(fullText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
    }
}
