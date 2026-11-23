import SwiftUI

/// Screen 9b · Locked feature (kids and other non-parents). Never shows prices or a pay
/// button: it explains the feature and offers "Ask a parent", which puts a request in the
/// parents' Inbox with an Unlock button that opens the paywall.
struct LockedFeatureSheet: View {
    let feature: PremiumFeature

    @EnvironmentObject private var store: FamilyStore
    @Environment(\.dismiss) private var dismiss

    private var parents: [Member] { store.family.members.filter { $0.role == .parent } }

    private var parentNames: String {
        parents.isEmpty ? "A parent" : parents.map(\.name).formatted(.list(type: .or))
    }

    var body: some View {
        let asked = store.hasAskedForPremium(feature)

        VStack(spacing: 0) {
            Text(feature.emoji)
                .font(.system(size: 30))
                .frame(width: 64, height: 64)
                .background(Theme.highSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.top, 30)
                .padding(.bottom, 14)
                .accessibilityHidden(true)

            Text("\(feature.shortTitle) is a Premium feature")
                .font(.system(size: 21, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)

            Text(feature.blurb)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(2)
                .padding(.top, 8)
                .padding(.horizontal, 10)

            HStack(spacing: 8) {
                AvatarStack(members: parents, size: 28, ring: Theme.surface2)
                Text("\(parentNames) can unlock it for the whole family")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.top, 18)

            Spacer(minLength: 20)

            Button {
                withAnimation(Theme.spring) { store.askForPremium(feature) }
            } label: {
                Text(asked ? "✓ Sent to \(parentNames)" : "🙋 Ask a parent")
                    .contentTransition(.opacity)
            }
            .buttonStyle(PrimaryButtonStyle(color: asked ? Theme.done : Theme.ink))
            .allowsHitTesting(!asked)
            .haptic(.success, trigger: asked) { _, sent in sent }

            Button(asked ? "Close" : "Maybe later") { dismiss() }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.ink2)
                .padding(.top, 12)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .presentationDetents([.height(430)])
        .presentationDragIndicator(.visible)
        .sheetCornerRadius(28)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            LockedFeatureSheet(feature: .starsRewards).previewEnvironment()
        }
}
