import SwiftUI

// Tablet design · the outer chrome around the phone screens.
// Expanded: sidebar (tabs, people, shortcuts, household card). Medium: floating top tabs + "New task".

// MARK: - Sidebar (expanded)

struct TabletSidebar: View {
    @EnvironmentObject private var store: FamilyStore
    @EnvironmentObject private var router: Router

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 18) {
                Spacer()
                Button { router.push(.search) } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Search tasks")
                Button { router.push(.newTask(templateID: nil)) } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New task")
            }
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(Theme.brand)
            .padding(.horizontal, 8)
            .padding(.top, 6)

            Text("FamilyTasks")
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(AppTab.allCases, id: \.self) { tabRow($0) }

                    header("People")
                    ForEach(store.family.members) { PersonRow(member: $0) }

                    if !store.family.templates.isEmpty {
                        header("Shortcuts")
                        ForEach(store.family.templates.prefix(6)) { template in
                            Button { router.push(.newTask(templateID: template.id)) } label: {
                                HStack(spacing: 12) {
                                    Text(template.emoji).font(.system(size: 16)).frame(width: 26)
                                    Text(template.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Theme.ink)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 10)
                                .frame(height: 38)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityHint("Opens New task, pre-filled")
                        }
                    }
                }
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)

            SidebarHouseholdCard()
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 12)
        .frame(width: TabletMetrics.sidebarWidth)
        .background(Theme.surface2.opacity(0.55).ignoresSafeArea())
    }

    private var homeCount: Int {
        store.homeTasks(scope: .mine, member: nil).filter { $0.status == .open }.count
    }

    private var inboxBadge: Bool {
        !store.incomingRequests.isEmpty || !store.premiumRequests.isEmpty
            || !store.pendingPlaceRequests.isEmpty
            || store.myPlaceRequests.contains { $0.status != .pending }
    }

    private func tabRow(_ tab: AppTab) -> some View {
        let isSelected = router.tab == tab
        return Button {
            router.tab = tab
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 17))
                    .frame(width: 24)
                Text(tab.title).font(.system(size: 16, weight: .semibold))
                Spacer()
                if tab == .home, homeCount > 0 {
                    Text("\(homeCount)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : Theme.ink3)
                }
                if tab == .inbox, inboxBadge {
                    Circle().fill(Theme.urgent).frame(width: 8, height: 8)
                }
            }
            .foregroundStyle(isSelected ? .white : Theme.ink)
            .padding(.horizontal, 10)
            .frame(height: 40)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.brand)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .haptic(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.ink3)
            .padding(.horizontal, 10)
            .padding(.top, 20)
            .padding(.bottom, 6)
    }
}

/// One tap shows only this person's tasks on Home. Drop a task card here to reassign it.
private struct PersonRow: View {
    @EnvironmentObject private var store: FamilyStore
    @EnvironmentObject private var router: Router
    let member: Member
    @State private var isTargeted = false

    var body: some View {
        let isSelected = router.tab == .home && router.homeMemberFilter == member.id
        let count = store.openCount(for: member.id)
        Button {
            withAnimation(Theme.spring) {
                router.homeMemberFilter = isSelected ? nil : member.id
                router.tab = .home
            }
        } label: {
            HStack(spacing: 12) {
                AvatarView(member: member, size: 26)
                Text(member.id == store.me.id ? "Me" : member.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer()
                if count > 0 {
                    Text("\(count)").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.ink3)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 40)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isTargeted ? Theme.brandSoft : (isSelected ? Theme.surface : .clear))
            }
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Theme.brand, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dropDestination(for: String.self) { items, _ in
            guard let text = items.first, let id = UUID(uuidString: text) else { return false }
            let done = withAnimation(Theme.spring) { store.reassign(id, to: member.id) }
            (done ? Haptic.success : Haptic.error).play()
            return done
        } isTargeted: { isTargeted = $0 }
        .animation(.quick(0.2), value: isTargeted)
        .accessibilityLabel("\(member.name), \(count) open tasks")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Small version of the household card for the sidebar footer: scene strip, name, week share bar.
struct SidebarHouseholdCard: View {
    @EnvironmentObject private var store: FamilyStore
    @EnvironmentObject private var router: Router

    var body: some View {
        TimelineView(.everyMinute) { context in
            let time = TimeOfDay(date: context.date)
            Button { router.tab = .family } label: { card(time: time) }
                .buttonStyle(PressableStyle())
                .animation(.easeInOut(duration: 1), value: time)
        }
    }

    private func card(time: TimeOfDay) -> some View {
        let members = store.family.members.filter { !$0.isInvited }
        let progress = members.map { ($0, store.weekProgress(for: $0.id)) }
        let done = progress.reduce(0) { $0 + $1.1.done }
        let total = progress.reduce(0) { $0 + $1.1.total }

        return VStack(alignment: .leading, spacing: 0) {
            StreetScene(time: time, isShown: true)
                .id(time)
                .transition(.opacity)
                .aspectRatio(308.0 / 92.0, contentMode: .fill)
                .frame(height: 44)
                .clipped()
            HStack(alignment: .top, spacing: 10) {
                Text("🏡")
                    .font(.system(size: 17))
                    .frame(width: 34, height: 34)
                    .background(.white, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
                    // Sits half over the scene; the text stays on the card's light background.
                    .padding(.top, -18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.family.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text("\(done) of \(total) done this week")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.ink2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            // Same rule as the big card: each person's colour is their share of the week's tasks.
            GeometryReader { geo in
                let shares = progress.filter { $0.1.done > 0 }
                let usable = max(geo.size.width - CGFloat(max(shares.count - 1, 0)) * 2, 0)
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.ink.opacity(0.08))
                    HStack(spacing: 2) {
                        ForEach(shares, id: \.0.id) { member, share in
                            Rectangle()
                                .fill(member.color)
                                .frame(width: total > 0 ? usable * CGFloat(share.done) / CGFloat(total) : 0)
                        }
                    }
                    .clipShape(Capsule())
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .background(LinearGradient(colors: time.cardColors, startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.black.opacity(0.06)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(store.family.name), \(done) of \(total) done this week")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Medium: floating top tabs + New task button

struct TabletTopTabBar: View {
    @EnvironmentObject private var store: FamilyStore
    @EnvironmentObject private var router: Router
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isSelected = router.tab == tab
                Button {
                    withAnimation(Theme.spring) { router.tab = tab }
                } label: {
                    Text(tab.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : Theme.ink2)
                        .padding(.horizontal, 16)
                        .frame(height: 34)
                        .background {
                            if isSelected {
                                Capsule().fill(Theme.ink).matchedGeometryEffect(id: "tab", in: namespace)
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            if tab == .inbox && hasInboxBadge {
                                Circle().fill(Theme.urgent).frame(width: 7, height: 7).offset(x: -6, y: 5)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .haptic(.selection, trigger: isSelected)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.line))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var hasInboxBadge: Bool {
        !store.incomingRequests.isEmpty || !store.premiumRequests.isEmpty
            || !store.pendingPlaceRequests.isEmpty
            || store.myPlaceRequests.contains { $0.status != .pending }
    }
}

struct NewTaskFloatingButton: View {
    @EnvironmentObject private var router: Router

    var body: some View {
        Button { router.push(.newTask(templateID: nil)) } label: {
            Label("New task", systemImage: "plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .frame(height: 50)
                .background(Theme.ink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        }
        .buttonStyle(PressableStyle())
        .padding(24)
    }
}

// MARK: - List + detail (expanded)

/// Expanded layout for Home and Inbox: the phone list in a narrow column, the picked task beside it.
struct TaskListDetail<List: View>: View {
    @Environment(\.layoutClass) private var layout
    @EnvironmentObject private var router: Router
    let tab: AppTab
    @ViewBuilder let list: List

    var body: some View {
        if layout == .expanded {
            HStack(spacing: 0) {
                list.frame(width: TabletMetrics.listWidth)
                Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea()
                Group {
                    if let id = router.selectedTask[tab] {
                        TaskDetailView(taskID: id, isPane: true)
                            .id(id)
                            .transition(.opacity)
                    } else {
                        DetailPlaceholder(systemImage: "checklist", title: "No task selected",
                                          message: "Pick a task on the left to see its details here.")
                    }
                }
                .frame(maxWidth: .infinity)
                .animation(.quick(0.2), value: router.selectedTask[tab])
            }
        } else {
            list
        }
    }
}

/// Expanded Family tab: the phone Family screen on the left, the picked member's profile on the right.
struct FamilyListDetail: View {
    @Environment(\.layoutClass) private var layout
    @EnvironmentObject private var store: FamilyStore
    @EnvironmentObject private var router: Router

    var body: some View {
        if layout == .expanded {
            HStack(spacing: 0) {
                FamilyView().frame(width: 400)
                Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea()
                Group {
                    if let id = router.selectedMember ?? store.family.members.first?.id {
                        MemberProfileView(memberID: id, isPane: true)
                            .frame(maxWidth: 640)
                            .frame(maxWidth: .infinity)
                            .id(id)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
                .animation(.quick(0.2), value: router.selectedMember)
            }
        } else {
            FamilyView()
        }
    }
}

// MARK: - New Task sheet (tablet)

/// Centred two-column sheet, ~900×690 (iOS 16 has no `.presentationSizing`, so it's drawn here).
struct NewTaskSheetOverlay: View {
    @EnvironmentObject private var router: Router
    let request: Router.NewTaskRequest
    let available: CGSize

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            NavigationStack {
                NewTaskView(templateID: request.templateID, editingTaskID: request.editingTaskID) {
                    withAnimation(Theme.spring) { router.newTask = nil }
                }
            }
            .frame(width: min(TabletMetrics.sheetSize.width, available.width - 40),
                   height: min(TabletMetrics.sheetSize.height, available.height - 40))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 12)
            .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
    }
}
