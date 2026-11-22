import SwiftUI

extension Color {
    /// `Color(hex: 0x3D5AFE)`
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Colours and sizes from design/index.html.
enum Theme {
    static let background = Color(hex: 0xF6F3EE)
    static let surface = Color.white
    static let surface2 = Color(hex: 0xF1EDE6)
    static let ink = Color(hex: 0x1F1B16)
    static let ink2 = Color(hex: 0x5E574D)
    static let ink3 = Color(hex: 0x9A9286)
    static let line = Color(hex: 0xE7E1D7)

    static let brand = Color(hex: 0x3D5AFE)
    static let brandSoft = Color(hex: 0xE8ECFF)
    static let done = Color(hex: 0x2E9E6B)
    static let doneSoft = Color(hex: 0xE3F5EC)
    static let urgent = Color(hex: 0xE5484D)
    static let urgentSoft = Color(hex: 0xFDECEC)
    static let high = Color(hex: 0xF59E0B)
    static let highText = Color(hex: 0xB26B00)
    static let highSoft = Color(hex: 0xFEF3DC)
    static let low = Color(hex: 0x8A8F98)
    static let lowSoft = Color(hex: 0xEFF0F2)
    static let purple = Color(hex: 0x8A63D2)

    static let cardRadius: CGFloat = 16

    /// The app's standard spring — snappy, with a little bounce.
    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.78)
}

// MARK: - Card

struct CardStyle: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(Theme.line)
            )
    }
}

extension View {
    func card(padding: CGFloat = 14) -> some View {
        modifier(CardStyle(padding: padding))
    }
}

// MARK: - Labels

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.7)
            .foregroundStyle(Theme.ink3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

struct ScreenTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(Theme.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Buttons

/// Shrinks slightly while pressed.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Full-width filled button (Send, Save, Mark as done).
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.ink

    func makeBody(configuration: Configuration) -> some View {
        FilledButtonBody(configuration: configuration, color: color, foreground: .white)
    }
}

private struct FilledButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let color: Color
    let foreground: Color
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(color, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .opacity(isEnabled ? 1 : 0.35)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

/// Full-width light button (Can't do it, Reopen).
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        FilledButtonBody(configuration: configuration, color: Theme.surface2, foreground: Theme.ink)
    }
}

/// Square icon button with an optional red dot (bell, more).
struct IconButton: View {
    let systemImage: String
    var showsDot = false
    var label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 40)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line))
                .overlay(alignment: .topTrailing) {
                    if showsDot {
                        Circle()
                            .fill(Theme.urgent)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                            .offset(x: -8, y: 8)
                            .transition(.scale)
                    }
                }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }
}
