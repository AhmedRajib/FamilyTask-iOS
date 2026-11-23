import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: FamilyStore
    @EnvironmentObject private var router: Router
    @State private var scope: HomeScope = .mine
    /// Tapping a face in the family strip shows only that person's tasks.
    @State private var memberFilter: UUID?
    /// Drives the first-time entrance. Stays true while Home is alive (e.g. coming back from a task).
    @State private var appeared = false

    var body: some View {
        let list = store.homeTasks(scope: scope, member: memberFilter)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header.reveal(appeared, order: 0, distance: -10)
                memberStrip
                stats.reveal(appeared, order: 2)
                filterControl.reveal(appeared, order: 3)
                taskList(list)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .startsEntrance($appeared, isActive: router.tab == .home)
        // Gives pushed pages a "‹ Home" back button.
        .navigationTitle("Home")
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink2)
                Text("Hi, \(store.me.name) 👋")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            IconButton(systemImage: "magnifyingglass", label: "Search tasks") {
                router.push(.search)
            }
            IconButton(systemImage: "bell", showsDot: !store.incomingRequests.isEmpty, label: "Inbox") {
                router.tab = .inbox
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Family strip

    private var memberStrip: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(Array(store.family.members.enumerated()), id: \.element.id) { index, member in
                    memberButton(member)
                        .popIn(appeared, order: 1 + index)
                }
                if store.permissions.canManageMembers {
                    Button { router.push(.addMember) } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.ink3)
                                .frame(width: 52, height: 52)
                                .overlay(Circle().strokeBorder(Theme.ink3, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                            Text("Invite").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.ink2)
                        }
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Add family member")
                    .popIn(appeared, order: 1 + store.family.members.count)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -2)
    }

    private func memberButton(_ member: Member) -> some View {
        let isSelected = memberFilter == member.id
        let count = store.openCount(for: member.id)
        return Button {
            withAnimation(Theme.spring) {
                memberFilter = isSelected ? nil : member.id
            }
        } label: {
            VStack(spacing: 6) {
                AvatarView(member: member, size: 48)
                    .padding(2)
                    .overlay(Circle().strokeBorder(isSelected ? Theme.ink : .clear, lineWidth: 2))
                    .scaleEffect(isSelected ? 1.06 : 1)
                    .overlay(alignment: .topTrailing) {
                        if count > 0 {
                            CountBadge(count: count)
                                .offset(x: 5, y: -3)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(Theme.spring, value: count)
                Text(member.id == store.me.id ? "Me" : member.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Theme.ink : Theme.ink2)
            }
        }
        .buttonStyle(PressableStyle())
        .haptic(.selection, trigger: isSelected)
        .accessibilityLabel("\(member.name), \(count) open tasks")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Stats

    private var stats: some View {
        HStack(spacing: 8) {
            StatTile(value: store.urgentCount, label: "Urgent", isHot: store.urgentCount > 0,
                     isShown: appeared, delay: 0.25)
            StatTile(value: store.dueTodayCount, label: "Due today", isShown: appeared, delay: 0.32)
            StatTile(value: store.doneTodayCount, label: "Done today", isShown: appeared, delay: 0.39)
        }
    }

    // MARK: - Filter

    @ViewBuilder
    private var filterControl: some View {
        if let id = memberFilter, let member = store.member(id) {
            HStack {
                AvatarView(member: member, size: 22)
                Text(member.id == store.me.id ? "Your tasks" : "\(member.name)'s tasks")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Show all") {
                    withAnimation(Theme.spring) { memberFilter = nil }
                }
                .font(.system(size: 14, weight: .semibold))
            }
            .frame(height: 38)
            .transition(.opacity)
        } else {
            PillSegmented(options: HomeScope.allCases, selection: $scope) { $0.rawValue }
                .transition(.opacity)
        }
    }

    // MARK: - List

    @ViewBuilder
    private func taskList(_ list: [FamilyTask]) -> some View {
        if list.isEmpty {
            EmptyStateView(emoji: "🎉", title: "All clear", message: "Nothing here right now. Tap ＋ to add a task.")
                .reveal(appeared, order: 4)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(Array(list.enumerated()), id: \.element.id) { index, task in
                    TaskCard(task: task)
                        .contentShape(Rectangle())
                        .onTapGesture { router.push(.taskDetail(task.id)) }
                        .accessibilityAddTraits(.isButton)
                        .reveal(appeared, order: 4 + index, distance: 26, step: 0.06)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.96).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .animation(Theme.spring, value: list.map(\.id))
        }
    }
}

private struct StatTile: View {
    let value: Int
    let label: String
    var isHot = false
    var isShown = true
    var delay: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            CountUpText(value: value, isShown: isShown, delay: delay)
                .font(.system(size: 24, weight: .bold))
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(isHot ? .white.opacity(0.85) : Theme.ink2)
        }
        .foregroundStyle(isHot ? .white : Theme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(isHot ? Theme.urgent : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(isHot ? Theme.urgent : Theme.line))
        .animation(Theme.spring, value: isHot)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack { HomeView() }.previewEnvironment()
}

/// Open-task count on a family face: rounded, even digits, always a neat circle (a pill from 10).
private struct CountBadge: View {
    let count: Int

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 11.5, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .contentTransition(.numericText())
            .padding(.horizontal, count > 9 ? 5 : 0)
            .frame(minWidth: 21, minHeight: 21)
            .background(Theme.ink, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.background, lineWidth: 2.5))
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            .accessibilityHidden(true)
    }
}
