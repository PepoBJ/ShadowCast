import SwiftUI

struct WelcomeDetailView: View {
    var body: some View {
        ZStack {
            CP.bg.ignoresSafeArea()
            VStack(spacing: 20) {
                // Glitchy icon
                ZStack {
                    Text("◈")
                        .font(.system(size: 64, weight: .ultraLight, design: .monospaced))
                        .foregroundStyle(CP.magenta)
                        .offset(x: -2, y: 1)
                        .opacity(0.5)
                    Text("◈")
                        .font(.system(size: 64, weight: .ultraLight, design: .monospaced))
                        .foregroundStyle(CP.cyan)
                        .offset(x: 2, y: -1)
                        .opacity(0.5)
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 52))
                        .foregroundStyle(CP.cyan)
                        .neonGlow(CP.cyan, radius: 8)
                }

                Text("SHADOW_CAST")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(CP.cyan)
                    .neonGlow(CP.cyan, radius: 6)
                    .tracking(6)

                Rectangle()
                    .frame(width: 160, height: 1)
                    .foregroundStyle(
                        LinearGradient(colors: [.clear, CP.cyan, .clear], startPoint: .leading, endPoint: .trailing)
                    )

                Text("SELECT AUDIO LOG FROM SIDEBAR")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(CP.dim)
                    .tracking(3)
            }
        }
    }
}
