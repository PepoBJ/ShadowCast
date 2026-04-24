import SwiftUI

struct WelcomeDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("ShadowCast")
                .font(.largeTitle)
                .fontWeight(.semibold)
            Text("Select a video from the sidebar to get started")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
