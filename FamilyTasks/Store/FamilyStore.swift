import SwiftUI
import Combine

enum HomeScope: String, CaseIterable {
    case mine = "Assigned to me"
    case byMe = "I assigned"
    case all = "All"
}

/// The app's single source of truth: the family, its tasks, and who is using the app.
final class FamilyStore: ObservableObject {
    @Published private(set) var family: Family
    @Published private(set) var tasks: [FamilyTask]
    @Published private(set) var currentMemberID: UUID

    /// Sends every change to the server (the local stand-in for now).
    private let onSave: (Family, [FamilyTask]) -> Void

    init(family: Family, tasks: [FamilyTask], currentMemberID: UUID,
         onSave: @escaping (Family, [FamilyTask]) -> Void) {
        self.family = family
        self.tasks = tasks
        self.currentMemberID = currentMemberID
        self.onSave = onSave
    }

    /// Sample family that saves nowhere, for SwiftUI previews.
    static func preview() -> FamilyStore {
        let sample = SampleData.make()
        return FamilyStore(family: sample.family, tasks: sample.tasks,
                           currentMemberID: sample.currentMemberID) { _, _ in }
    }

    // MARK: - Lookups

    var me: Member { member(currentMemberID) ?? family.members[0] }
    var permissions: Permissions { Permissions(actor: me) }

    func member(_ id: UUID) -> Member? { family.members.first { $0.id == id } }
    func members(_ ids: [UUID]) -> [Member] { ids.compactMap(member) }
    func task(_ id: UUID) -> FamilyTask? { tasks.first { $0.id == id } }
    func place(_ id: UUID?) -> Place? { family.places.first { $0.id == id } }
    func time(_ id: UUID?) -> TimeShortcut? { family.times.first { $0.id == id } }
    func template(_ id: UUID?) -> TaskTemplate? { family.templates.first { $0.id == id } }

    /// The place a location reminder points to: its own one-off place, or a family place.
    func place(for location: LocationReminder?) -> Place? {
        guard let location else { return nil }
        return location.custom ?? place(location.placeID)
    }

    /// Private tasks are visible only to the person who created them.
    var visibleTasks: [FamilyTask] {
        tasks.filter { !$0.isPrivate || $0.creatorID == currentMemberID }
    }

    // MARK: - Home

    func homeTasks(scope: HomeScope, member: UUID?) -> [FamilyTask] {
        let me = currentMemberID
        let base: [FamilyTask]
        if let member {
            base = visibleTasks.filter { $0.assigneeIDs.contains(member) }
        } else {
            switch scope {
            case .mine: base = visibleTasks.filter { $0.assigneeIDs.contains(me) }
            case .byMe: base = visibleTasks.filter { $0.creatorID == me && $0.assigneeIDs != [me] }
            case .all: base = visibleTasks
            }
        }
        // Finished tasks stay on the list for the rest of the day, then drop off.
        return base
            .filter { !$0.isDone || Self.isToday($0.completedAt) }
            .sorted { Self.listOrder($0, $1) }
    }

    private var myOpenTasks: [FamilyTask] {
        visibleTasks.filter {
            $0.assigneeIDs.contains(currentMemberID) && ($0.status == .open || $0.status == .requested)
        }
    }

    var urgentCount: Int { myOpenTasks.filter { $0.priority == .urgent }.count }
    var dueTodayCount: Int { myOpenTasks.filter { Self.isToday($0.dueDate) }.count }
    var doneTodayCount: Int {
        visibleTasks.filter {
            $0.assigneeIDs.contains(currentMemberID) && $0.isDone && Self.isToday($0.completedAt)
        }.count
    }

    func openCount(for memberID: UUID) -> Int {
        visibleTasks.filter { $0.assigneeIDs.contains(memberID) && $0.status == .open }.count
    }

    /// Done vs total for tasks due (or finished) this week.
    func weekProgress(for memberID: UUID) -> (done: Int, total: Int) {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: .now) else { return (0, 0) }
        let mine = visibleTasks.filter { task in
            guard task.assigneeIDs.contains(memberID), task.status != .declined else { return false }
            let date = task.completedAt ?? task.dueDate ?? task.createdAt
            return week.contains(date)
        }
        return (mine.filter(\.isDone).count, mine.count)
    }

    // MARK: - Calendar

    func tasks(on day: Date) -> [FamilyTask] {
        let calendar = Calendar.current
        return visibleTasks
            .filter { task in
                guard task.status != .declined, let due = task.dueDate else { return false }
                return calendar.isDate(due, inSameDayAs: day)
            }
            .sorted { ($0.isAllDay ? .distantPast : $0.dueDate!) < ($1.isAllDay ? .distantPast : $1.dueDate!) }
    }

    // MARK: - Inbox

    /// Requests waiting for my answer.
    var incomingRequests: [FamilyTask] {
        visibleTasks.filter { $0.status == .requested && $0.assigneeIDs.contains(currentMemberID) }
    }

    /// Tasks I created that someone else finished — the "creator is told on completion" rule.
    var completedForMe: [FamilyTask] {
        tasks
            .filter { $0.isDone && $0.creatorID == currentMemberID && $0.completedByID != currentMemberID }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    var declinedForMe: [FamilyTask] {
        tasks.filter { $0.status == .declined && $0.creatorID == currentMemberID }
    }

    // MARK: - Changes

    func add(_ task: FamilyTask) {
        tasks.append(task)
        save()
    }

    func toggleDone(_ id: UUID) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }

        if tasks[i].isDone {
            // Reopen, and take back the repeat copy if nobody has touched it.
            if let nextID = tasks[i].nextOccurrenceID,
               let n = tasks.firstIndex(where: { $0.id == nextID }),
               tasks[n].status == .open, !tasks[n].checklist.contains(where: \.isDone) {
                tasks.remove(at: n)
            }
            guard let j = tasks.firstIndex(where: { $0.id == id }) else { return }
            tasks[j].status = .open
            tasks[j].completedAt = nil
            tasks[j].completedByID = nil
            tasks[j].nextOccurrenceID = nil
        } else {
            tasks[i].status = .done
            tasks[i].completedAt = .now
            tasks[i].completedByID = currentMemberID
            if let next = nextOccurrence(of: tasks[i]) {
                tasks[i].nextOccurrenceID = next.id
                tasks.append(next)
            }
        }
        save()
    }

    private func nextOccurrence(of task: FamilyTask) -> FamilyTask? {
        guard let due = task.dueDate, var nextDue = task.repeatRule.next(after: due) else { return nil }
        // Skip ahead past any days that were missed.
        while nextDue < .now, let later = task.repeatRule.next(after: nextDue) { nextDue = later }

        var copy = task
        copy.id = UUID()
        copy.status = .open
        copy.dueDate = nextDue
        copy.completedAt = nil
        copy.completedByID = nil
        copy.nextOccurrenceID = nil
        copy.createdAt = .now
        copy.checklist = task.checklist.map { ChecklistItem(title: $0.title) }
        return copy
    }

    func toggleChecklistItem(task taskID: UUID, item itemID: UUID) {
        guard let i = tasks.firstIndex(where: { $0.id == taskID }),
              let j = tasks[i].checklist.firstIndex(where: { $0.id == itemID }) else { return }
        tasks[i].checklist[j].isDone.toggle()
        save()
    }

    func accept(_ id: UUID) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].status = .open
        save()
    }

    func decline(_ id: UUID, reason: String?) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].status = .declined
        let trimmed = reason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        tasks[i].declineReason = trimmed.isEmpty ? nil : trimmed
        save()
    }

    func delete(_ id: UUID) {
        tasks.removeAll { $0.id == id }
        save()
    }

    /// DEBUG: look at the app as another member, to check permissions.
    func switchUser(to id: UUID) {
        guard member(id) != nil else { return }
        currentMemberID = id
    }

    // MARK: - Members (parents only — the server will enforce the same rules)

    var parentCount: Int { family.members.filter { $0.role == .parent }.count }

    /// Creates the profile and its first invite. The role is set here, never by the person joining.
    @discardableResult
    func addMember(name: String, role: Role, colorHex: UInt32) -> Member? {
        guard permissions.canManageMembers else { return nil }
        let member = Member(name: name, role: role, colorHex: colorHex, invite: LocalServer.makeInvite())
        family.members.append(member)
        save()
        return member
    }

    func updateMember(_ id: UUID, name: String, colorHex: UInt32) {
        guard let i = index(of: id), permissions.canManageMembers || id == currentMemberID else { return }
        family.members[i].name = name
        family.members[i].colorHex = colorHex
        save()
    }

    /// Whether `id` can be given `role`. The last parent can't be downgraded.
    func canChangeRole(of id: UUID, to role: Role) -> Bool {
        guard permissions.canManageMembers, let m = member(id) else { return false }
        if m.role == .parent && role != .parent && parentCount <= 1 { return false }
        return true
    }

    func setRole(_ id: UUID, to role: Role) {
        guard canChangeRole(of: id, to: role), let i = index(of: id) else { return }
        family.members[i].role = role
        save()
    }

    /// A fresh one-time code. With `signOutDevices`, existing devices stop working ("Set up a new phone").
    @discardableResult
    func newInvite(for id: UUID, signOutDevices: Bool) -> Invite? {
        guard permissions.canManageMembers, let i = index(of: id) else { return nil }
        let invite = LocalServer.makeInvite()
        family.members[i].invite = invite
        if signOutDevices { family.members[i].devices = [] }
        save()
        return invite
    }

    func signOutAllDevices(of id: UUID) {
        guard permissions.canManageMembers, let i = index(of: id) else { return }
        family.members[i].devices = []
        family.members[i].invite = nil
        save()
    }

    func canRemove(_ id: UUID) -> Bool {
        guard permissions.canManageMembers, id != currentMemberID, let m = member(id) else { return false }
        return !(m.role == .parent && parentCount <= 1)
    }

    /// Removes the profile and their devices. Tasks only they were doing go too.
    func removeMember(_ id: UUID) {
        guard canRemove(id) else { return }
        family.members.removeAll { $0.id == id }
        for i in tasks.indices { tasks[i].assigneeIDs.removeAll { $0 == id } }
        tasks.removeAll { $0.assigneeIDs.isEmpty || ($0.isPrivate && $0.creatorID == id) }
        save()
    }

    private func index(of id: UUID) -> Int? { family.members.firstIndex { $0.id == id } }

    // MARK: - Shortcuts (parents & adults — shared by the whole family)

    /// Adds the template, or replaces the one with the same id.
    func saveTemplate(_ template: TaskTemplate) {
        guard permissions.canManageShortcuts else { return }
        upsert(template, into: &family.templates)
        save()
    }

    func deleteTemplate(_ id: UUID) {
        guard permissions.canManageShortcuts else { return }
        family.templates.removeAll { $0.id == id }
        save()
    }

    func savePlace(_ place: Place) {
        guard permissions.canManageShortcuts else { return }
        upsert(place, into: &family.places)
        save()
    }

    /// Quick tasks that used it keep working without a place. Existing tasks are left alone.
    func deletePlace(_ id: UUID) {
        guard permissions.canManageShortcuts else { return }
        family.places.removeAll { $0.id == id }
        for i in family.templates.indices where family.templates[i].placeID == id {
            family.templates[i].placeID = nil
        }
        save()
    }

    func saveTime(_ time: TimeShortcut) {
        guard permissions.canManageShortcuts else { return }
        upsert(time, into: &family.times)
        family.times.sort { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
        save()
    }

    /// Quick tasks that used it keep working without a set time. Existing tasks are left alone.
    func deleteTime(_ id: UUID) {
        guard permissions.canManageShortcuts else { return }
        family.times.removeAll { $0.id == id }
        for i in family.templates.indices where family.templates[i].timeShortcutID == id {
            family.templates[i].timeShortcutID = nil
        }
        save()
    }

    func templates(usingPlace id: UUID) -> [TaskTemplate] { family.templates.filter { $0.placeID == id } }
    func templates(usingTime id: UUID) -> [TaskTemplate] { family.templates.filter { $0.timeShortcutID == id } }

    private func upsert<T: Identifiable>(_ item: T, into list: inout [T]) {
        if let i = list.firstIndex(where: { $0.id == item.id }) { list[i] = item } else { list.append(item) }
    }

    // MARK: - Premium (one subscription for the whole family)

    var isPremium: Bool { family.premium?.isActive ?? false }

    /// Open tasks with a location reminder — free families get `PremiumFeature.freeLocationReminders`.
    var activeLocationReminderCount: Int {
        tasks.filter { $0.location != nil && ($0.status == .open || $0.status == .requested) }.count
    }

    var canAddLocationReminder: Bool {
        isPremium || activeLocationReminderCount < PremiumFeature.freeLocationReminders
    }

    /// Called after a parent subscribes (or on launch, when their subscription renewed).
    func activatePremium(productID: String, expiresAt: Date, isTrial: Bool) {
        guard permissions.canPay else { return }
        family.premium = PremiumStatus(productID: productID, expiresAt: expiresAt,
                                       isTrial: isTrial, purchasedBy: currentMemberID)
        family.premiumRequests = []
        save()
    }

    /// Requests waiting for a parent, newest first.
    var premiumRequests: [PremiumRequest] {
        guard permissions.canPay, !isPremium else { return [] }
        return (family.premiumRequests ?? []).sorted { $0.date > $1.date }
    }

    func hasAskedForPremium(_ feature: PremiumFeature) -> Bool {
        (family.premiumRequests ?? []).contains { $0.memberID == currentMemberID && $0.feature == feature }
    }

    func askForPremium(_ feature: PremiumFeature) {
        guard !hasAskedForPremium(feature) else { return }
        family.premiumRequests = (family.premiumRequests ?? []) + [PremiumRequest(memberID: currentMemberID, feature: feature)]
        save()
    }

    func dismissPremiumRequest(_ id: UUID) {
        family.premiumRequests?.removeAll { $0.id == id }
        save()
    }

    // MARK: - Helpers

    private func save() {
        onSave(family, tasks)
    }

    private static func isToday(_ date: Date?) -> Bool {
        date.map(Calendar.current.isDateInToday) ?? false
    }

    /// Open before done; then most urgent; then soonest due.
    static func listOrder(_ a: FamilyTask, _ b: FamilyTask) -> Bool {
        if a.isDone != b.isDone { return !a.isDone }
        if a.isDone { return (a.completedAt ?? .distantPast) > (b.completedAt ?? .distantPast) }
        if a.priority != b.priority { return a.priority.rank > b.priority.rank }
        switch (a.dueDate, b.dueDate) {
        case let (x?, y?): return x < y
        case (.some, nil): return true
        case (nil, .some): return false
        case (nil, nil): return a.createdAt > b.createdAt
        }
    }
}
