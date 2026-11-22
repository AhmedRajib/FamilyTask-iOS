import Combine
import SwiftUI

/// Shows the right thing when someone reaches a Premium feature:
/// parents see the payment screen (9), everyone else gets "Ask a parent" (9b).
final class PremiumGate: ObservableObject {
    @Published var showPaywall = false
    @Published var lockedFeature: PremiumFeature?
    /// The feature that led to the paywall, so it can be highlighted.
    @Published private(set) var paywallFeature: PremiumFeature?

    /// True if the feature can be used now. Otherwise presents the paywall or the
    /// "Ask a parent" sheet and returns false.
    func allows(_ feature: PremiumFeature, in store: FamilyStore, unlocked: Bool? = nil) -> Bool {
        if unlocked ?? store.isPremium { return true }
        present(for: feature, in: store)
        return false
    }

    func present(for feature: PremiumFeature?, in store: FamilyStore) {
        if store.permissions.canPay {
            paywallFeature = feature
            showPaywall = true
        } else if let feature {
            lockedFeature = feature
        }
    }
}

/// Small "PREMIUM" tag next to locked features.
struct PremiumTag: View {
    var body: some View {
        Text("PREMIUM")
            .font(.system(size: 9.5, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(Theme.highText)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Theme.highSoft, in: Capsule())
    }
}
