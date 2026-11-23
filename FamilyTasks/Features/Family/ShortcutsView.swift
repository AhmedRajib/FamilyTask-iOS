import SwiftUI

/// Family shortcuts: quick tasks, places and times, saved once and reused by everyone.
/// Parents and adults can add (＋ Add / "Add …" rows), edit (tap) and delete (swipe or the edit page).
/// Children see the list read-only; tapping a quick task starts a new task from it.
struct ShortcutsView: View {
    @EnvironmentObject private var store: FamilyStore
    @EnvironmentObject private var router: Router

    @State private var showAddMenu = false
    @State private var pendingDelete: PendingDelete?

    private enum PendingDelete: Identifiable {
        case template(TaskTemplate), place(Place), time(TimeShortcut)

        var id: UUID {
            switch self {
            case .template(let t): t.id
            case .place(let p): p.id
            case .time(let t): t.id
            }
        }
    }

    private var canManage: Bool { store.permissions.canManageShortcuts }

    var body: some View {
        List {
            Section {
                Text(canManage
                     ? "Save it once, and everyone in the family can reuse it in one tap."
                     : "Saved by your parents. Tap a quick task to use it.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink2)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
            }

            templatesSection
            placesSection
            timesSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 10)
        .background(Theme.background)
        .navigationTitle("Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            if canManage {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddMenu = true } label: { Label("Add", systemImage: "plus").labelStyle(.titleAndIcon) }
                }
            }
        }
        .confirmationDialog("What do you want to add?", isPresented: $showAddMenu, titleVisibility: .visible) {
            Button("⚡ Quick task") { router.push(.editTemplate(nil)) }
            Button("📍 Place") { router.push(.editPlace(nil)) }
            Button("🕐 Time") { router.push(.editTime(nil)) }
        }
        .alert(deleteTitle, isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
        ), presenting: pendingDelete) { item in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { delete(item) }
        } message: { item in
            Text(deleteMessage(for: item))
        }
    }

    // MARK: - Sections

    private var templatesSection: some View {
        Section {
            ForEach(store.family.templates) { template in
                Button {
                    router.push(canManage ? .editTemplate(template.id) : .newTask(templateID: template.id))
                } label: {
                    row(emoji: template.emoji, title: template.title, detail: detail(for: template))
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if canManage {
                        Button("Delete", role: .destructive) { pendingDelete = .template(template) }
                    }
                }
                .swipeActions(edge: .leading) {
                    if canManage {
                        Button { router.push(.newTask(templateID: template.id)) } label: {
                            Label("Use", systemImage: "bolt.fill")
                        }
                        .tint(Theme.brand)
                    }
                }
            }
            if canManage { addRow("Add quick task") { router.push(.editTemplate(nil)) } }
        } header: {
            header("⚡ Quick tasks")
        } footer: {
            if store.family.templates.isEmpty && !canManage { emptyFooter("No quick tasks yet.") }
        }
        .listRowBackground(Theme.surface)
        .listRowInsets(EdgeInsets())
    }

    private var placesSection: some View {
        Section {
            ForEach(store.family.places) { place in
                Button {
                    router.push(.editPlace(place.id))
                } label: {
                    row(emoji: place.emoji, title: place.name,
                        detail: [place.address, place.radiusText].filter { !$0.isEmpty }.joined(separator: " · "),
                        chevron: canManage)
                }
                .buttonStyle(.plain)
                .disabled(!canManage)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if canManage {
                        Button("Delete", role: .destructive) { pendingDelete = .place(place) }
                    }
                }
            }
            if canManage { addRow("Add place") { router.push(.editPlace(nil)) } }
        } header: {
            header("📍 Places")
        } footer: {
            if store.family.places.isEmpty && !canManage { emptyFooter("No places yet.") }
        }
        .listRowBackground(Theme.surface)
        .listRowInsets(EdgeInsets())
    }

    private var timesSection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                ForEach(store.family.times) { time in
                    Button { router.push(.editTime(time.id)) } label: {
                        HStack(spacing: 10) {
                            Text(time.emoji).font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(time.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                Text(time.timeText).font(.system(size: 12)).foregroundStyle(Theme.ink2)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(!canManage)
                    .contextMenu {
                        if canManage {
                            Button { router.push(.editTime(time.id)) } label: { Label("Edit", systemImage: "pencil") }
                            Button(role: .destructive) { pendingDelete = .time(time) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .accessibilityLabel("\(time.name), \(time.timeText)")
                }
                if canManage {
                    Button { router.push(.editTime(nil)) } label: {
                        Label("Add time", systemImage: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.brand)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Theme.brandSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(10)
        } header: {
            header("🕐 Times")
        } footer: {
            if canManage && !store.family.times.isEmpty {
                emptyFooter("Tap a time to change it. Press and hold to delete.")
            } else if store.family.times.isEmpty && !canManage {
                emptyFooter("No times yet.")
            }
        }
        .listRowBackground(Theme.surface)
        .listRowInsets(EdgeInsets())
    }

    // MARK: - Pieces

    private func header(_ text: String) -> some View {
        SectionLabel(text).padding(.horizontal, -4).textCase(nil)
    }

    private func emptyFooter(_ text: String) -> some View {
        Text(text).font(.system(size: 12)).foregroundStyle(Theme.ink3)
    }

    private func addRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.brand)
                    .frame(width: 32, height: 32)
                    .background(Theme.brandSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.brand)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func detail(for template: TaskTemplate) -> String {
        var parts: [String] = []
        if let place = store.place(template.placeID) { parts.append(place.name) }
        if let time = store.time(template.timeShortcutID) { parts.append(time.timeText) }
        if template.repeatRule != .never { parts.append(template.repeatRule.title) }
        parts.append(template.priority.title)
        return parts.joined(separator: " · ")
    }

    private func row(emoji: String, title: String, detail: String, chevron: Bool = true) -> some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 17))
                .frame(width: 32, height: 32)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(detail).font(.system(size: 12)).foregroundStyle(Theme.ink3).lineLimit(1)
            }
            Spacer()
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Delete

    private var deleteTitle: String {
        switch pendingDelete {
        case .template(let t): "Delete \"\(t.title)\"?"
        case .place(let p): "Delete \"\(p.name)\"?"
        case .time(let t): "Delete \"\(t.name)\"?"
        case nil: "Delete?"
        }
    }

    private func deleteMessage(for item: PendingDelete) -> String {
        switch item {
        case .template: "It's removed for the whole family. Tasks already created from it don't change."
        case .place(let p): FamilyTasks.deleteMessage(usedBy: store.templates(usingPlace: p.id), losing: "a place")
        case .time(let t): FamilyTasks.deleteMessage(usedBy: store.templates(usingTime: t.id), losing: "a set time")
        }
    }

    private func delete(_ item: PendingDelete) {
        withAnimation(Theme.spring) {
            switch item {
            case .template(let t): store.deleteTemplate(t.id)
            case .place(let p): store.deletePlace(p.id)
            case .time(let t): store.deleteTime(t.id)
            }
        }
        Haptic.success.play()
    }
}

#Preview {
    NavigationStack { ShortcutsView() }.previewEnvironment()
}
