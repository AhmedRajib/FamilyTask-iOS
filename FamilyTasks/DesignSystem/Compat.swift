import SwiftUI
import UIKit

// iOS 16-safe stand-ins for iOS 17 APIs. On iOS 17+ the native versions are used where they exist.

// MARK: - Haptics (iOS 17: .sensoryFeedback)

enum Haptic {
    case selection, success, error, light

    func play() {
        switch self {
        case .selection: UISelectionFeedbackGenerator().selectionChanged()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error: UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

private struct HapticModifier<T: Equatable>: ViewModifier {
    let haptic: Haptic
    let trigger: T
    let condition: ((T, T) -> Bool)?
    @State private var previous: T?

    func body(content: Content) -> some View {
        content
            .onAppear { previous = trigger }
            .onChange(of: trigger) { new in
                let old = previous ?? new
                previous = new
                if condition?(old, new) ?? true { haptic.play() }
            }
    }
}

extension View {
    /// Plays a haptic when `trigger` changes (and `condition(old, new)` is true, if given).
    func haptic<T: Equatable>(_ haptic: Haptic, trigger: T, condition: ((T, T) -> Bool)? = nil) -> some View {
        modifier(HapticModifier(haptic: haptic, trigger: trigger, condition: condition))
    }
}

// MARK: - SF Symbol effects (iOS 17 only; no effect on iOS 16)

extension View {
    @ViewBuilder
    func bounceEffect<V: Equatable>(value: V) -> some View {
        if #available(iOS 17.0, *) {
            symbolEffect(.bounce, value: value)
        } else {
            modifier(SpringBounce(value: value))
        }
    }

    @ViewBuilder
    func pulseEffect(isActive: Bool) -> some View {
        if #available(iOS 17.0, *) {
            symbolEffect(.pulse, options: .repeating, isActive: isActive)
        } else {
            modifier(Pulse(isActive: isActive))
        }
    }

    /// Sheet corner radius (iOS 16.4+).
    @ViewBuilder
    func sheetCornerRadius(_ radius: CGFloat) -> some View {
        if #available(iOS 16.4, *) {
            presentationCornerRadius(radius)
        } else {
            self
        }
    }
}

// MARK: - Animation (iOS 17: .snappy)

extension Animation {
    static var quick: Animation { .spring(response: 0.3, dampingFraction: 0.86) }
    static func quick(_ duration: Double) -> Animation { .spring(response: duration, dampingFraction: 0.86) }
}

// MARK: - Empty / missing content (iOS 17: ContentUnavailableView)

struct UnavailableView: View {
    let title: String
    let systemImage: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.ink3)
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.ink)
            if let message {
                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

// MARK: - iOS 16 versions of the symbol bounce and pulse

/// Pops up and springs back whenever `value` changes, like iOS 17's `.symbolEffect(.bounce)`.
private struct SpringBounce<V: Equatable>: ViewModifier {
    let value: V
    @State private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: value) { _ in
                withAnimation(.spring(response: 0.16, dampingFraction: 0.6)) { scale = 1.22 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) { scale = 1 }
                }
            }
    }
}

/// Fades in and out while active, like iOS 17's repeating `.symbolEffect(.pulse)`.
private struct Pulse: ViewModifier {
    let isActive: Bool
    @State private var dimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(isActive && dimmed ? 0.35 : 1)
            .onAppear(perform: update)
            .onChange(of: isActive) { _ in update() }
    }

    private func update() {
        guard isActive else {
            withAnimation(.default) { dimmed = false }
            return
        }
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { dimmed = true }
    }
}
