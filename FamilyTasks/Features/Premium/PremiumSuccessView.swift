import SwiftUI

/// Screen 9c · Payment success. Shown inside the paywall after a purchase or restore:
/// confirms every member is covered, when the trial ends and where to cancel, then
/// suggests the first Premium thing to try.
struct PremiumSuccessView: View {
    let subscription: ActiveSubscription
    /// The feature that opened the paywall, used for the "try it now" button.
    let feature: PremiumFeature?
    let onFinish: (Route?) -> Void

    @EnvironmentObject private var store: FamilyStore
    @ObservedObject private var premium = PremiumStore.shared
    @State private var appeared = false

    private var plan: PremiumPlan { PremiumPlan.plan(for: subscription.productID) ?? .yearly }

    /// Everyone else in the family — they're the ones this purchase unlocks.
    private var others: [Member] { store.family.members.filter { $0.id != store.me.id } }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    checkmark
                    Text("Welcome to Premium!")
                        .font(.system(size: 23, weight: .bold))
                        .tracking(-0.4)
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 36)
                        .accessibilityAddTraits(.isHeader)
                    Text("Everyone in **\(store.family.name)** is unlocked.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 270)
                        .padding(.top, 6)

                    if !others.isEmpty { memberList.padding(.top, 26) }
                    renewalInfo.padding(.top, 12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 12) {
                if let next = nextStep {
                    Button(next.title) { onFinish(next.route) }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Done") { onFinish(nil) }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.ink2)
                } else {
                    Button("Done") { onFinish(nil) }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) { appeared = true } }
    }

    private var checkmark: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 38, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 84, height: 84)
            .background(Theme.done, in: Circle())
            .background(Circle().fill(Theme.doneSoft).frame(width: 112, height: 112))
            .scaleEffect(appeared ? 1 : 0.4)
            .opacity(appeared ? 1 : 0)
            .accessibilityHidden(true)
    }

    private var memberList: some View {
        VStack(spacing: 0) {
            ForEach(Array(others.enumerated()), id: \.element.id) { index, member in
                HStack(spacing: 12) {
                    AvatarView(member: member, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(member.name)
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(member.devices.first?.name ?? (member.isInvited ? "Not joined yet" : member.role.title))
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.ink3)
                    }
                    Spacer(minLength: 8)
                    Pill(text: "Premium", foreground: Theme.done, background: Theme.doneSoft)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                if index < others.count - 1 { RowDivider(leading: 58) }
            }
        }
        .card(padding: 0)
    }

    private var renewalInfo: some View {
        let date = subscription.expiresAt.formatted(.dateTime.day().month(.wide))
        let price = "\(premium.price(plan))\(plan.shortPeriod)"
        let headline = subscription.isTrial ? "Free trial until \(date)" : "Premium until \(date)"
        let body = subscription.isTrial
            ? "Then \(price). Manage or cancel in Family → Premium."
            : "Renews at \(price). Manage or cancel in Family → Premium."
        return VStack(alignment: .leading, spacing: 2) {
            Text(headline).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink)
            Text(body).font(.system(size: 12)).foregroundStyle(Theme.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line))
    }

    /// The first thing to try, based on what brought them to the paywall.
    /// Features that aren't built yet get no button.
    private var nextStep: (title: String, route: Route)? {
        switch feature {
        case .locationReminders: ("Add a location reminder 📍", .newTask(templateID: nil))
        case .customSounds: ("Choose your own sounds 🎵", .sounds)
        case .urgentRing, .starsRewards, nil: nil
        }
    }
}

#Preview {
    PremiumSuccessView(
        subscription: ActiveSubscription(productID: PremiumPlan.yearly.productID,
                                         expiresAt: .now.addingTimeInterval(7 * 24 * 3600),
                                         isTrial: true, willRenew: true),
        feature: .customSounds,
        onFinish: { _ in }
    )
    .background(Theme.background)
    .previewEnvironment()
}
