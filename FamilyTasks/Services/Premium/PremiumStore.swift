import Combine
import Foundation
import StoreKit
import UIKit
import UserNotifications

/// The three Family Premium plans.
enum PremiumPlan: String, CaseIterable, Identifiable {
    case yearly, sixMonths, monthly

    var id: Self { self }

    /// Must match the products created in App Store Connect (and FamilyTasks.storekit for testing).
    var productID: String {
        switch self {
        case .yearly: "com.ahmed.rajib.familytasks.premium.yearly"
        case .sixMonths: "com.ahmed.rajib.familytasks.premium.sixmonths"
        case .monthly: "com.ahmed.rajib.familytasks.premium.monthly"
        }
    }

    var title: String {
        switch self {
        case .yearly: "Yearly"
        case .sixMonths: "6 months"
        case .monthly: "Monthly"
        }
    }

    var months: Int {
        switch self {
        case .yearly: 12
        case .sixMonths: 6
        case .monthly: 1
        }
    }

    /// "/year", "every 6 months", "/month"
    var periodText: String {
        switch self {
        case .yearly: "per year"
        case .sixMonths: "every 6 months"
        case .monthly: "per month"
        }
    }

    /// Shown only when the App Store can't be reached. Real prices always come from Apple.
    var fallbackPrice: Decimal {
        switch self {
        case .yearly: Decimal(string: "29.99")!
        case .sixMonths: Decimal(string: "17.99")!
        case .monthly: Decimal(string: "3.99")!
        }
    }

    static func plan(for productID: String) -> PremiumPlan? {
        allCases.first { $0.productID == productID }
    }
}

/// A subscription found on this Apple ID.
struct ActiveSubscription: Equatable {
    let productID: String
    let expiresAt: Date
    let isTrial: Bool
    let willRenew: Bool
}

/// StoreKit 2 purchases for Family Premium. Approach adapted from SafeguardNote's
/// StoreKitManager (copied, not shared). Prices always come from the App Store, so every
/// country sees its own local price.
///
/// TODO with the backend: send each verified transaction to the FamilyTasks server, which
/// marks the whole family as Premium on every phone (including Android).
final class PremiumStore: ObservableObject {
    static let shared = PremiumStore()

    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var trialEligible = true
    @Published private(set) var subscription: ActiveSubscription?
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?
    private var didLoad = false

    private init() {
        updatesTask = Task { [weak self] in
            // Renewals, refunds, and purchases approved later ("Ask to Buy").
            for await result in Transaction.updates {
                guard let self, case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self.refreshSubscription()
            }
        }
    }

    var storeAvailable: Bool { !products.isEmpty }

    func product(for plan: PremiumPlan) -> Product? { products[plan.productID] }

    // MARK: - Loading

    func load() async {
        guard !didLoad, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: PremiumPlan.allCases.map(\.productID))
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            if let yearly = products[PremiumPlan.yearly.productID]?.subscription {
                trialEligible = await yearly.isEligibleForIntroOffer
            }
            didLoad = !loaded.isEmpty
        } catch {
            print("FamilyTasks: couldn't load products – \(error)")
        }
        await refreshSubscription()
    }

    // MARK: - Prices

    func price(_ plan: PremiumPlan) -> String {
        if let product = product(for: plan) { return product.displayPrice }
        return plan.fallbackPrice.formatted(.currency(code: "USD"))
    }

    /// The plan's price spread over its months, e.g. "$2.50".
    func monthlyPrice(_ plan: PremiumPlan) -> String {
        if let product = product(for: plan) {
            return (product.price / Decimal(plan.months)).formatted(product.priceFormatStyle)
        }
        return (plan.fallbackPrice / Decimal(plan.months)).formatted(.currency(code: "USD"))
    }

    /// Percent saved compared with paying monthly, e.g. 37.
    func savingPercent(_ plan: PremiumPlan) -> Int {
        guard plan != .monthly else { return 0 }
        let monthly = product(for: .monthly)?.price ?? PremiumPlan.monthly.fallbackPrice
        let total = product(for: plan)?.price ?? plan.fallbackPrice
        guard monthly > 0 else { return 0 }
        let ratio = NSDecimalNumber(decimal: total / (monthly * Decimal(plan.months))).doubleValue
        return Int(((1 - ratio) * 100).rounded())
    }

    /// Whether this plan starts with the free week.
    func hasTrial(_ plan: PremiumPlan) -> Bool {
        guard trialEligible else { return false }
        if let offer = product(for: plan)?.subscription?.introductoryOffer {
            return offer.paymentMode == .freeTrial
        }
        // Without the store, follow the plan: the trial is on Yearly only.
        return plan == .yearly && !storeAvailable
    }

    func trialLength(_ plan: PremiumPlan) -> String {
        guard let period = product(for: plan)?.subscription?.introductoryOffer?.period else { return "7-day" }
        switch period.unit {
        case .day: return "\(period.value)-day"
        case .week: return period.value == 1 ? "7-day" : "\(period.value * 7)-day"
        case .month: return "\(period.value)-month"
        case .year: return "\(period.value)-year"
        @unknown default: return "free"
        }
    }

    // MARK: - Buying

    enum Outcome {
        case purchased(ActiveSubscription)
        case pending
        case cancelled
        case failed
    }

    func purchase(_ plan: PremiumPlan) async -> Outcome {
        guard let product = product(for: plan) else {
            errorMessage = storeUnavailableMessage
            return .failed
        }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else {
                    errorMessage = "The App Store couldn't confirm this purchase. You haven't been charged twice. Try Restore."
                    return .failed
                }
                await transaction.finish()
                await refreshSubscription()
                guard let subscription else { return .failed }
                if subscription.isTrial { scheduleTrialReminder(for: subscription, plan: plan) }
                return .purchased(subscription)
            case .pending:
                errorMessage = "Waiting for approval. Premium unlocks as soon as the purchase is approved."
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed
            }
        } catch {
            errorMessage = error.localizedDescription
            return .failed
        }
    }

    /// "Restore": asks the App Store for this Apple ID's purchases.
    func restore() async -> ActiveSubscription? {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
        await refreshSubscription()
        if subscription == nil {
            errorMessage = "No active Premium subscription was found for this Apple ID."
        }
        return subscription
    }

    /// Reads the current subscription from StoreKit.
    @discardableResult
    func refreshSubscription() async -> ActiveSubscription? {
        var best: ActiveSubscription?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  PremiumPlan.plan(for: transaction.productID) != nil,
                  let expires = transaction.expirationDate, expires > .now else { continue }
            var willRenew = true
            if let status = try? await products[transaction.productID]?.subscription?.status.first,
               case .verified(let info) = status.renewalInfo {
                willRenew = info.willAutoRenew
            }
            let found = ActiveSubscription(
                productID: transaction.productID,
                expiresAt: expires,
                isTrial: transaction.offerType == .introductory,
                willRenew: willRenew
            )
            if best == nil || expires > best!.expiresAt { best = found }
        }
        subscription = best
        return best
    }

    /// Opens Apple's own "manage subscription" sheet (change plan or cancel).
    func showManageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene else { return }
        try? await AppStore.showManageSubscriptions(in: scene)
        await refreshSubscription()
    }

    var storeUnavailableMessage: String {
        #if DEBUG
        "The App Store isn't connected. Run the app from Xcode: the FamilyTasks scheme uses FamilyTasks.storekit for test purchases."
        #else
        "Purchases aren't available right now. Check your connection and try again."
        #endif
    }

    // MARK: - Trial reminder

    /// Keeps the paywall's promise: "We'll remind you 2 days before the trial ends."
    private func scheduleTrialReminder(for subscription: ActiveSubscription, plan: PremiumPlan) {
        let remindAt = subscription.expiresAt.addingTimeInterval(-2 * 24 * 3600)
        guard remindAt > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = "Your free trial ends in 2 days"
        content.body = "Family Premium then renews at \(price(plan)) \(plan.periodText). You can cancel any time in Family → Premium."
        content.sound = .default
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: remindAt)
        let request = UNNotificationRequest(
            identifier: "trial-reminder",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        )
        Task {
            guard await NotificationManager.shared.requestPermission() else { return }
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}
