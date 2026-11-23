import SwiftUI

// Entrance and attention animations. All of them respect Reduce Motion
// (they fall back to a plain fade, or nothing).

extension Animation {
    /// Soft spring used for things arriving on screen.
    static let entrance = Animation.spring(response: 0.55, dampingFraction: 0.82)
}

// MARK: - Staggered reveal

/// Rises and fades in when `isShown` turns true, `order` steps after the first item.
/// Drive every item from one parent flag so lazily created rows (scrolled in later) just appear.
private struct Reveal: ViewModifier {
    let isShown: Bool
    let order: Int
    let distance: CGFloat
    let step: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isShown ? 1 : 0)
            .offset(y: isShown || reduceMotion ? 0 : distance)
            .scaleEffect(isShown || reduceMotion ? 1 : 0.97, anchor: .top)
            .animation(reduceMotion
                       ? .easeOut(duration: 0.2)
                       : .entrance.delay(Double(min(order, 12)) * step),
                       value: isShown)
    }
}

/// Pops in from small, for avatars and icons.
private struct PopIn: ViewModifier {
    let isShown: Bool
    let order: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isShown ? 1 : 0)
            .scaleEffect(isShown || reduceMotion ? 1 : 0.4)
            .animation(reduceMotion
                       ? .easeOut(duration: 0.2)
                       : .spring(response: 0.5, dampingFraction: 0.6).delay(0.05 + Double(min(order, 12)) * 0.06),
                       value: isShown)
    }
}

extension View {
    /// Sets `flag` to true once the screen is really on screen and laid out.
    /// - `isActive`: tabs are all kept alive (hidden ones are just transparent), so a tab's
    ///   `onAppear` fires at launch while invisible. Pass `router.tab == .family` so the
    ///   entrance waits until the tab is actually shown — and then plays once.
    /// - The short wait lets lazy stacks build their rows first, so they have something to animate.
    func startsEntrance(_ flag: Binding<Bool>, isActive: Bool = true) -> some View {
        task(id: isActive) {
            guard isActive, !flag.wrappedValue else { return }
            try? await Task.sleep(nanoseconds: 60_000_000)
            flag.wrappedValue = true
        }
    }

    func reveal(_ isShown: Bool, order: Int = 0, distance: CGFloat = 18, step: Double = 0.055) -> some View {
        modifier(Reveal(isShown: isShown, order: order, distance: distance, step: step))
    }

    func popIn(_ isShown: Bool, order: Int = 0) -> some View {
        modifier(PopIn(isShown: isShown, order: order))
    }

    /// A soft light sweep across the view every few seconds (CTA buttons, badges).
    func shimmer(every interval: Double = 3.2, active: Bool = true) -> some View {
        modifier(Shimmer(interval: interval, active: active))
    }
}

// MARK: - Shimmer

private struct Shimmer: ViewModifier {
    let interval: Double
    let active: Bool
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if active && !reduceMotion {
                    GeometryReader { geo in
                        LinearGradient(colors: [.white.opacity(0), .white.opacity(0.35), .white.opacity(0)],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * 0.45)
                            .rotationEffect(.degrees(18))
                            .offset(x: phase * geo.size.width * 1.5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                    .task {
                        // Sweep, rest, repeat. Cancelled automatically when the view goes away.
                        try? await Task.sleep(nanoseconds: 900_000_000)
                        while !Task.isCancelled {
                            phase = -1
                            withAnimation(.easeInOut(duration: 1.1)) { phase = 1 }
                            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                        }
                    }
                }
            }
    }
}

// MARK: - Count up

/// Counts from 0 to `value` the first time it appears, then rolls digits on change.
struct CountUpText: View {
    let value: Int
    let isShown: Bool
    var delay: Double = 0

    var body: some View {
        Text("\(isShown ? value : 0)")
            .contentTransition(.numericText())
            .animation(.spring(response: 0.7, dampingFraction: 0.9).delay(delay), value: isShown)
            .animation(Theme.spring, value: value)
    }
}
