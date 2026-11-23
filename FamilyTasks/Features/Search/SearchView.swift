import SwiftUI

/// Search every task you can see: title, note, checklist items, people and places.
/// Private tasks of other members never appear (uses `visibleTasks`).
struct SearchView: View {
    @EnvironmentObject private var store: FamilyStore
    @EnvironmentObject private var router: Router
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var filter: Filter = .all
    @FocusState private var focused: Bool
    @AppStorage("recentSearches") private var recentRaw = ""

    enum Filter: String, CaseIterable {
        case all = "All"
        case urgent = "⚡ Urgent"
        case mine = "Mine"
        case today = "Today"
        case done = "Done"
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            filterChips
            ScrollView {
                content
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Wait for the push animation before raising the keyboard.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
                TextField("Search tasks, people, places", text: $query)
                    .font(.system(size: 16))
                    .focused($focused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit { remember(query) }
                if !query.isEmpty {
                    Button {
                        withAnimation(.quick) { query = "" }
                        focused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.ink3)
                    }
                    .accessibilityLabel("Clear search")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(focused ? Theme.ink : Theme.line, lineWidth: focused ? 1.5 : 1))
            .animation(.quick, value: focused)

            Button("Cancel") { dismiss() }
                .font(.system(size: 16, weight: .medium))
                .tint(Theme.brand)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var filterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(Filter.allCases, id: \.self) { option in
                    let isOn = filter == option
                    Button {
                        withAnimation(.quick) { filter = option }
                    } label: {
                        Text(option.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isOn ? .white : Theme.ink2)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(isOn ? Theme.ink : Theme.surface, in: Capsule())
                            .overlay(Capsule().strokeBorder(isOn ? Theme.ink : Theme.line))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .haptic(.selection, trigger: filter)
    }

    // MARK: - Results

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    @ViewBuilder
    private var content: some View {
        if trimmed.isEmpty && filter == .all {
            suggestions
        } else {
            let found = results
            if found.isEmpty {
                EmptyStateView(
                    emoji: "🔍",
                    title: "No tasks found",
                    message: trimmed.isEmpty ? "Nothing matches this filter." : "Nothing matches “\(trimmed)”. Try a name, a place or another word."
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(found.count) \(found.count == 1 ? "task" : "tasks")")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                        .padding(.horizontal, 4)
                    LazyVStack(spacing: 10) {
                        ForEach(found) { task in
                            TaskCard(task: task)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    remember(query)
                                    router.push(.taskDetail(task.id))
                                }
                                .accessibilityAddTraits(.isButton)
                                .transition(.opacity)
                        }
                    }
                }
                .animation(Theme.spring, value: found.map(\.id))
            }
        }
    }

    private var results: [FamilyTask] {
        let me = store.me.id
        return store.visibleTasks
            .filter { task in
                switch filter {
                case .all: return task.status != .declined
                case .urgent: return task.priority == .urgent && task.status == .open
                case .mine: return task.assigneeIDs.contains(me) && task.status != .declined
                case .today: return task.dueDate.map(Calendar.current.isDateInToday) ?? false
                case .done: return task.isDone
                }
            }
            .filter { trimmed.isEmpty || matches($0, trimmed) }
            .sorted { FamilyStore.listOrder($0, $1) }
    }

    /// Every word must appear somewhere: "milk nadia" finds Nadia's task with milk on the list.
    private func matches(_ task: FamilyTask, _ text: String) -> Bool {
        var haystack = [task.title, task.notes] + task.checklist.map(\.title)
        haystack += store.members(task.assigneeIDs).map(\.name)
        if let creator = store.member(task.creatorID) { haystack.append(creator.name) }
        if let location = task.location, let place = store.place(for: location) {
            haystack += [place.name, place.address]
        }
        let joined = haystack.joined(separator: " ")
        return text.split(separator: " ").allSatisfy {
            joined.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    // MARK: - Before typing

    private var recent: [String] {
        recentRaw.split(separator: "\n").map(String.init)
    }

    private func remember(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let list = [t] + recent.filter { $0.caseInsensitiveCompare(t) != .orderedSame }
        recentRaw = list.prefix(6).joined(separator: "\n")
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !recent.isEmpty {
                HStack {
                    SectionLabel("Recent")
                    Button("Clear") { withAnimation(.quick) { recentRaw = "" } }
                        .font(.system(size: 13, weight: .semibold))
                        .tint(Theme.brand)
                }
                .padding(.bottom, 8)
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.offset) { index, text in
                        Button { query = text } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath").foregroundStyle(Theme.ink3)
                                Text(text).foregroundStyle(Theme.ink)
                                Spacer()
                                Image(systemName: "arrow.up.left").font(.system(size: 13)).foregroundStyle(Theme.ink3)
                            }
                            .font(.system(size: 15))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < recent.count - 1 { RowDivider(leading: 44) }
                    }
                }
                .card(padding: 0)
                .padding(.bottom, 22)
            }

            SectionLabel("Search by person").padding(.bottom, 8)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(store.family.members) { member in
                        Button { query = member.name } label: {
                            HStack(spacing: 7) {
                                AvatarView(member: member, size: 24)
                                Text(member.id == store.me.id ? "Me" : member.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.ink)
                            }
                            .padding(.leading, 5)
                            .padding(.trailing, 12)
                            .padding(.vertical, 5)
                            .background(Theme.surface, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.line))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)

            if !store.family.places.isEmpty {
                SectionLabel("Search by place").padding(.top, 22).padding(.bottom, 8)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(store.family.places) { place in
                            Button { query = place.name } label: {
                                Text("\(place.emoji) \(place.name)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Theme.ink)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Theme.surface, in: Capsule())
                                    .overlay(Capsule().strokeBorder(Theme.line))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(.vertical, 1)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

#Preview {
    NavigationStack { SearchView() }.previewEnvironment()
}
