import SwiftUI

// MARK: - Cyberpunk Color Palette
enum CP {
    static let bg         = Color(red: 0.04, green: 0.04, blue: 0.08)      // near-black
    static let bgPanel    = Color(red: 0.06, green: 0.06, blue: 0.12)      // panel bg
    static let bgSelected = Color(red: 0.0,  green: 0.9,  blue: 1.0).opacity(0.08) // selected row
    static let cyan       = Color(red: 0.0,  green: 0.9,  blue: 1.0)       // neon cyan
    static let magenta    = Color(red: 1.0,  green: 0.0,  blue: 0.6)       // neon magenta
    static let yellow     = Color(red: 1.0,  green: 0.9,  blue: 0.0)       // neon yellow
    static let orange     = Color(red: 1.0,  green: 0.5,  blue: 0.0)       // neon orange
    static let green      = Color(red: 0.0,  green: 1.0,  blue: 0.4)       // neon green
    static let red        = Color(red: 1.0,  green: 0.1,  blue: 0.2)       // neon red
    static let dim        = Color.white.opacity(0.35)
    static let dimmer     = Color.white.opacity(0.18)
    static let border     = Color(red: 0.0,  green: 0.9,  blue: 1.0).opacity(0.3)
}

// MARK: - Cyberpunk Button Style
struct CyberpunkButtonStyle: ButtonStyle {
    var color: Color = CP.cyan

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(configuration.isPressed ? CP.bg : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                configuration.isPressed ? color : color.opacity(0.12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(color, lineWidth: 1)
            )
            .cornerRadius(2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}

// MARK: - Glowing text modifier
struct NeonGlow: ViewModifier {
    var color: Color
    var radius: CGFloat = 4
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.8), radius: radius)
            .shadow(color: color.opacity(0.4), radius: radius * 2)
    }
}

extension View {
    func neonGlow(_ color: Color, radius: CGFloat = 4) -> some View {
        modifier(NeonGlow(color: color, radius: radius))
    }
}
