import SwiftUI

/// Links the App Store requires on the payment screen.
enum PremiumLinks {
    /// Apple's standard licence agreement. Swap for your own terms if you publish them.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// TODO: set the FamilyTasks privacy policy URL before submitting. The link is hidden while nil.
    static let privacy: URL? = nil
}

extension PremiumPlan {
    /// "/year", "/6 months", "/month"
    var shortPeriod: String {
        switch self {
        case .yearly: "/year"
        case .sixMonths: "/6 months"
        case .monthly: "/month"
        }
    }
}

/// Screen 9 · Payment (parents). Opens full screen from Family → Premium, a locked feature,
/// or an "Unlock" in the Inbox. After a purchase it turns into screen 9c (success).
struct PaywallView: View {
    /// The feature that led here; its perk is highlighted.
    var feature: PremiumFeature?

    @EnvironmentObject private var store: FamilyStore
    @EnvironmentObject private var router: Router
    @ObservedObject private var premium = PremiumStore.shared
    @Environment(\.dismiss) private var dismiss

    /// Yearly is pre-selected so the saving is obvious.
    @State private var plan: PremiumPlan = .yearly
    @State private var purchased: ActiveSubscription?
    /// Drives the entrance: hero → perks → plans → button.
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [.init(color: Color(hex: 0xFFF8EC), location: 0),
                        .init(color: Theme.background, location: 0.45)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            if let purchased {
                PremiumSuccessView(subscription: purchased, feature: feature, onFinish: finish)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                paywall.transition(.opacity)
            }
        }
        .haptic(.success, trigger: purchased != nil) { _, done in done }
        .task { await premium.load() }
        .startsEntrance($appeared)
        .alert("Family Premium", isPresented: Binding(
            get: { premium.errorMessage != nil },
            set: { if !$0 { premium.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(premium.errorMessage ?? "")
        }
    }

    // MARK: - Paywall

    private var paywall: some View {
        VStack(spacing: 0) {
            topBar
                .reveal(appeared, order: 0, distance: -8)
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    perks.padding(.vertical, 16)
                    plans
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            cta
                .reveal(appeared, order: 9, distance: 40)
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink2)
                    .frame(width: 30, height: 30)
                    .background(.black.opacity(0.06), in: Circle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Close")
            Spacer()
            Button("Restore", action: restore)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink2)
                .disabled(premium.isPurchasing)
        }
        .padding(.horizontal, 20)
        .frame(height: 44)
    }

    private var hero: some View {
        let joined = store.family.members.filter { !$0.isInvited }
        return VStack(spacing: 0) {
            heroAvatars(Array((joined.isEmpty ? store.family.members : joined).prefix(4)))
            Text("✨ FAMILY PREMIUM")
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(Theme.highText)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.highSoft, in: Capsule())
                .shimmer(every: 4)
                .padding(.top, 12)
                .reveal(appeared, order: 2)
            Text("One plan for the whole family")
                .font(.system(size: 23, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(Theme.ink)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)
                .reveal(appeared, order: 3)
            Text("Everyone in **\(store.family.name)** gets Premium, on iPhone and Android.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink2)
                .padding(.top, 6)
                .reveal(appeared, order: 4)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    /// The family's faces pop in one by one, slightly overlapping.
    private func heroAvatars(_ members: [Member]) -> some View {
        HStack(spacing: -14) {
            ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                AvatarView(member: member, size: 44, ring: Color(hex: 0xFFF8EC))
                    .popIn(appeared, order: index)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(members.map(\.name).formatted(.list(type: .and)))
    }

    private var perks: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
            ForEach(Array(PremiumFeature.allCases.enumerated()), id: \.element) { index, perk in
                let highlighted = perk == feature
                HStack(spacing: 7) {
                    Text(perk.emoji).font(.system(size: 16))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(perk.title)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        if !perk.isAvailable {
                            Text("Coming soon")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Theme.ink3)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 9)
                .padding(.vertical, 8)
                .frame(maxHeight: .infinity)
                .background(highlighted ? Theme.highSoft : Theme.surface,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(highlighted ? Theme.high : Theme.line, lineWidth: highlighted ? 1.5 : 1)
                )
                .reveal(appeared, order: 5 + index / 2, distance: 12)
            }
        }
    }

    private var plans: some View {
        VStack(spacing: 8) {
            ForEach(Array(PremiumPlan.allCases.enumerated()), id: \.element) { index, option in
                Button {
                    withAnimation(.quick) { plan = option }
                } label: {
                    PlanRow(plan: option, isSelected: plan == option, premium: premium)
                }
                .buttonStyle(.plain)
                .reveal(appeared, order: 7 + index, distance: 24)
                .haptic(.selection, trigger: plan == option) { _, on in on }
            }
        }
        .padding(.top, 9) // room for the "Best value" badge
    }

    private var cta: some View {
        VStack(spacing: 8) {
            Button(action: buy) {
                if premium.isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text(ctaTitle).contentTransition(.opacity)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .shimmer(active: !premium.isPurchasing)
            .disabled(premium.isPurchasing)

            Text(finePrint)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Link(destination: PremiumLinks.terms) { Text("Terms").underline() }
                if let privacy = PremiumLinks.privacy {
                    Text("·")
                    Link(destination: privacy) { Text("Privacy").underline() }
                }
            }
            .font(.system(size: 10.5))
            .foregroundStyle(Theme.ink3)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private var ctaTitle: String {
        premium.hasTrial(plan)
            ? "Start \(premium.trialLength(plan)) free trial"
            : "Subscribe for \(premium.price(plan))\(plan.shortPeriod)"
    }

    private var finePrint: String {
        if premium.hasTrial(plan) {
            return "No payment today. We'll remind you 2 days before the trial ends. Cancel anytime."
        }
        return "\(premium.price(plan)) \(plan.periodText), renews automatically until cancelled. Cancel anytime."
    }

    // MARK: - Actions

    private func buy() {
        let chosen = plan
        Task {
            if case .purchased(let subscription) = await premium.purchase(chosen) {
                complete(with: subscription)
            }
        }
    }

    private func restore() {
        Task {
            if let subscription = await premium.restore() {
                complete(with: subscription)
            }
        }
    }

    private func complete(with subscription: ActiveSubscription) {
        store.activatePremium(productID: subscription.productID,
                              expiresAt: subscription.expiresAt,
                              isTrial: subscription.isTrial)
        withAnimation(Theme.spring) { purchased = subscription }
    }

    /// Closes the paywall and, if asked, opens the first Premium thing to try.
    private func finish(_ route: Route?) {
        dismiss()
        guard let route else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { router.push(route) }
    }
}

// MARK: - Plan row

private struct PlanRow: View {
    let plan: PremiumPlan
    let isSelected: Bool
    @ObservedObject var premium: PremiumStore

    private var saving: Int { premium.savingPercent(plan) }

    private var badge: String? {
        guard plan == .yearly else { return nil }
        return saving > 0 ? "BEST VALUE · SAVE \(saving)%" : "BEST VALUE"
    }

    private var detail: String {
        let price = premium.price(plan)
        if premium.hasTrial(plan) {
            return "\(premium.trialLength(plan)) free trial, then \(price)\(plan.shortPeriod)"
        }
        if saving > 0 { return "\(price) \(plan.periodText) · Save \(saving)%" }
        return "\(price) \(plan.periodText)"
    }

    var body: some View {
        HStack(spacing: 11) {
            Circle()
                .strokeBorder(isSelected ? Theme.ink : Theme.line, lineWidth: isSelected ? 6 : 2)
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(plan.title)
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.ink2)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(premium.monthlyPrice(plan))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("/month")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.ink2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, badge == nil ? 11 : 15)
        .padding(.bottom, 11)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(isSelected ? Theme.ink : Theme.line, lineWidth: isSelected ? 2 : 1.5)
        )
        .overlay(alignment: .topLeading) {
            if let badge {
                Text(badge)
                    .font(.system(size: 9.5, weight: .heavy))
                    .tracking(0.76)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.ink, in: Capsule())
                    .offset(x: 14, y: -9)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    PaywallView(feature: .locationReminders).previewEnvironment()
}
