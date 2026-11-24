import SwiftUI

/// Signed out → Welcome. Signed in without a family → Create or join. Otherwise the app.
struct RootView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        Group {
            switch session.phase {
            case .signedOut:
                WelcomeView().transition(.opacity)
            case .needsFamily:
                CreateOrJoinView().transition(.opacity)
            case .ready:
                if let store = session.store {
                    MainTabsView()
                        .environmentObject(store)
                        // A different family or person gets a fresh app (tabs, stacks).
                        .id(ObjectIdentifier(store))
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: session.phase)
    }
}

struct MainTabsView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var store: FamilyStore
    @StateObject private var router = Router()
    @StateObject private var gate = PremiumGate()

    var body: some View {
        ZStack {
            // All tabs stay alive so each keeps its scroll position and navigation stack.
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isSelected = router.tab == tab
                NavigationStack(path: router.path(for: tab)) {
                    rootView(for: tab)
                        .navigationDestination(for: Route.self) { RouteView(route: $0) }
                }
                .opacity(isSelected ? 1 : 0)
                .allowsHitTesting(isSelected)
                .accessibilityHidden(!isSelected)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Hidden on pushed pages such as New Task, which have their own bottom button.
            if router.isAtRoot {
                FamilyTabBar()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.quick(0.3), value: router.isAtRoot)
        .environmentObject(router)
        .environmentObject(gate)
        // 9 · Payment (parents) and 9b · Locked feature (everyone else).
        .fullScreenCover(isPresented: $gate.showPaywall) {
            PaywallView(feature: gate.paywallFeature)
                .environmentObject(store)
                .environmentObject(router)
        }
        .sheet(item: $gate.lockedFeature) { feature in
            LockedFeatureSheet(feature: feature).environmentObject(store)
        }
        .task { await syncPremium() }
        .onAppear {
            // Right after creating a family, go straight to adding the first member.
            guard session.shouldPromptAddMember else { return }
            session.shouldPromptAddMember = false
            router.tab = .family
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { router.push(.addMember) }
        }
    }

    /// Picks up renewals (or a purchase made on another device with this Apple ID) on launch.
    private func syncPremium() async {
        let premium = PremiumStore.shared
        await premium.load()
        guard store.permissions.canPay, let subscription = premium.subscription,
              subscription.expiresAt > (store.family.premium?.expiresAt ?? .distantPast) else { return }
        store.activatePremium(productID: subscription.productID,
                              expiresAt: subscription.expiresAt,
                              isTrial: subscription.isTrial)
    }

    @ViewBuilder
    private func rootView(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView()
        case .calendar: CalendarView()
        case .family: FamilyView()
        case .inbox: InboxView()
        }
    }
}

struct RouteView: View {
    let route: Route

    var body: some View {
        switch route {
        case .newTask(let templateID): NewTaskView(templateID: templateID)
        case .editTask(let id): NewTaskView(templateID: nil, editingTaskID: id)
        case .taskDetail(let id): TaskDetailView(taskID: id)
        case .shortcuts: ShortcutsView()
        case .editTemplate(let id): TemplateEditorView(templateID: id)
        case .editPlace(let id): PlaceEditorView(placeID: id)
        case .editTime(let id): TimeEditorView(timeID: id)
        case .reviewPlaceRequest(let id): PlaceEditorView(placeID: nil, requestID: id)
        case .addMember: AddMemberView()
        case .invite(let id): InviteView(memberID: id)
        case .memberProfile(let id): MemberProfileView(memberID: id)
        case .search: SearchView()
        case .sounds: SoundsView()
        case .tonePicker(let kind): TonePickerView(kind: kind)
        }
    }
}

// MARK: - Tab bar with the centre ＋ button

struct FamilyTabBar: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var store: FamilyStore

    var body: some View {
        HStack(spacing: 0) {
            item(.home)
            item(.calendar)
            Button {
                router.push(.newTask(templateID: nil))
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(Theme.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.28), radius: 10, y: 6)
            }
            .buttonStyle(PressableStyle())
            .offset(y: -16)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("New task")
            .haptic(.light, trigger: router.isAtRoot) { _, atRoot in !atRoot }
            item(.family)
            item(.inbox, badge: !store.incomingRequests.isEmpty || !store.premiumRequests.isEmpty
                   || !store.pendingPlaceRequests.isEmpty
                   || store.myPlaceRequests.contains { $0.status != .pending })
        }
        .padding(.top, 8)
        .frame(height: 58, alignment: .top)
        // The divider sits in the background so the raised ＋ button covers it.
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                Theme.surface.ignoresSafeArea(edges: .bottom)
                Rectangle().fill(Theme.line).frame(height: 1)
            }
        }
    }

    private func item(_ tab: AppTab, badge: Bool = false) -> some View {
        let isSelected = router.tab == tab
        return Button {
            router.tab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 20))
                    .bounceEffect(value: isSelected)
                    .overlay(alignment: .topTrailing) {
                        if badge {
                            Circle().fill(Theme.urgent).frame(width: 8, height: 8).offset(x: 4, y: -2)
                        }
                    }
                Text(tab.title).font(.system(size: 10.5, weight: .medium))
            }
            .foregroundStyle(isSelected ? Theme.brand : Theme.ink3)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .haptic(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    MainTabsView().previewEnvironment()
}
