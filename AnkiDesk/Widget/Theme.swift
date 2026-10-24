import SwiftUI

struct Theme {
    let background: Color
    /// Translucent themes draw a blurred desktop behind the background colour.
    let translucent: Bool
    let foreground: Color
    let muted: Color
    let line: Color
    let track: Color
    let new: Color
    let learn: Color
    let review: Color
    let numberDesign: Font.Design
    let numberWeight: Font.Weight
    let numberSize: CGFloat
    let textDesign: Font.Design
    let isDark: Bool

    func number(_ size: CGFloat? = nil) -> Font {
        .system(size: size ?? numberSize, weight: numberWeight, design: numberDesign)
    }

    func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: textDesign)
    }

    static func of(_ id: ThemeID) -> Theme {
        switch id {
        case .paper:
            Theme(background: Color(hex: 0xF7F4EE), translucent: false, foreground: Color(hex: 0x1C1B19),
                  muted: Color(hex: 0x6B665E), line: Color(hex: 0x1C1B19, opacity: 0.10), track: Color(hex: 0x1C1B19, opacity: 0.08),
                  new: Color(hex: 0x2563C9), learn: Color(hex: 0xC2410C), review: Color(hex: 0x2E7D4F),
                  numberDesign: .serif, numberWeight: .regular, numberSize: 68, textDesign: .default, isDark: false)
        case .midnight:
            Theme(background: Color(hex: 0x181A21, opacity: 0.78), translucent: true, foreground: Color(hex: 0xF2F3F5),
                  muted: Color(hex: 0xA3A8B4), line: Color.white.opacity(0.10), track: Color.white.opacity(0.10),
                  new: Color(hex: 0x7AB0FF), learn: Color(hex: 0xFF9A6B), review: Color(hex: 0x62D394),
                  numberDesign: .default, numberWeight: .semibold, numberSize: 60, textDesign: .default, isDark: true)
        case .matcha:
            Theme(background: Color(hex: 0xE4EBDC), translucent: false, foreground: Color(hex: 0x1E2A1B),
                  muted: Color(hex: 0x4E5D48), line: Color(hex: 0x1E2A1B, opacity: 0.12), track: Color(hex: 0x1E2A1B, opacity: 0.10),
                  new: Color(hex: 0x2D5FA8), learn: Color(hex: 0xA33D12), review: Color(hex: 0x2F6B3A),
                  numberDesign: .serif, numberWeight: .medium, numberSize: 62, textDesign: .default, isDark: false)
        case .terminal:
            Theme(background: Color(hex: 0x0C110D), translucent: false, foreground: Color(hex: 0xCFF5C9),
                  muted: Color(hex: 0x86AD82), line: Color(hex: 0xCFF5C9, opacity: 0.16), track: Color(hex: 0xCFF5C9, opacity: 0.12),
                  new: Color(hex: 0x7FC8FF), learn: Color(hex: 0xFFB86B), review: Color(hex: 0x8CF08A),
                  numberDesign: .monospaced, numberWeight: .medium, numberSize: 52, textDesign: .monospaced, isDark: true)
        }
    }
}

extension ThemeID {
    var title: String {
        switch self {
        case .paper: "Paper"
        case .midnight: "Midnight"
        case .matcha: "Matcha"
        case .terminal: "Terminal"
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

private struct WidgetBlurKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Off when rendering to an image, where the desktop blur can't be drawn.
    var widgetBlur: Bool {
        get { self[WidgetBlurKey.self] }
        set { self[WidgetBlurKey.self] = newValue }
    }
}

/// The widget's card: theme background, optional blur, rounded corners and a hairline border.
struct WidgetBackground: ViewModifier {
    let theme: Theme
    var radius: CGFloat = 20
    @Environment(\.widgetBlur) private var blur

    func body(content: Content) -> some View {
        content
            .foregroundStyle(theme.foreground)
            .background {
                ZStack {
                    if theme.translucent && blur { VisualEffect() }
                    theme.background
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(theme.line))
            .environment(\.colorScheme, theme.isDark ? .dark : .light)
    }
}

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

extension View {
    func widgetCard(_ theme: Theme, radius: CGFloat = 20) -> some View {
        modifier(WidgetBackground(theme: theme, radius: radius))
    }
}
