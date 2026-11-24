import SwiftUI

/// Tablet design · layout rules. The layout follows the width of the app's window, not the device,
/// so iPad Split View and Slide Over fall back to the phone layout by themselves.
///
/// - compact  (< 600 pt): phone layout, bottom tab bar with the centre ＋.
/// - medium   (600 – 899): floating top tabs, "New task" button, one wide pane, 2-column cards.
/// - expanded (≥ 900): sidebar, then list + detail side by side.
enum LayoutClass: Equatable {
    case compact, medium, expanded

    init(width: CGFloat) {
        switch width {
        case ..<600: self = .compact
        case ..<900: self = .medium
        default: self = .expanded
        }
    }

    var isTablet: Bool { self != .compact }
}

private struct LayoutClassKey: EnvironmentKey {
    static let defaultValue: LayoutClass = .compact
}

extension EnvironmentValues {
    var layoutClass: LayoutClass {
        get { self[LayoutClassKey.self] }
        set { self[LayoutClassKey.self] = newValue }
    }
}

/// Width of the list column next to a detail pane (design: 360 – 392).
enum TabletMetrics {
    static let listWidth: CGFloat = 372
    static let sidebarWidth: CGFloat = 248
    static let detailMaxWidth: CGFloat = 900
    static let sheetSize = CGSize(width: 900, height: 690)
}

/// Empty right-hand pane before anything is picked.
struct DetailPlaceholder: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Theme.ink3)
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ink)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}
