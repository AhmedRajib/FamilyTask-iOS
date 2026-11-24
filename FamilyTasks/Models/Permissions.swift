import Foundation

enum AssignAbility {
    /// Goes straight onto their list.
    case direct
    /// Arrives as a request they can accept or decline (child → adult).
    case request
    case notAllowed
}

/// Who can do what. Rules agreed in the design discussion:
/// - Everyone can create tasks for themselves.
/// - Parents and adults can assign to anyone.
/// - Children can only *ask* adults, and can't assign to other children.
/// - Children can't send Urgent to anyone else.
/// - Editing: the creator, any parent, or an adult when a child is one of the assignees.
///   Children can only edit tasks they created. Finished tasks are locked (reopen first).
/// - Deleting: only the creator or a parent.
/// - Assignees can complete or decline.
struct Permissions {
    let actor: Member
    /// Everyone in the family, so the rules can see who a task is assigned to.
    var members: [Member] = []

    func assignAbility(to target: Member) -> AssignAbility {
        if target.id == actor.id { return .direct }
        switch actor.role {
        case .parent, .adult:
            return .direct
        case .child:
            return target.role == .child ? .notAllowed : .request
        }
    }

    func canUseUrgent(assignees: Set<UUID>) -> Bool {
        actor.role != .child || assignees == [actor.id]
    }

    func canEdit(_ task: FamilyTask) -> Bool {
        guard !task.isDone else { return false }
        if task.creatorID == actor.id { return true }
        switch actor.role {
        case .parent: return true
        case .adult: return isForAChild(task)
        case .child: return false
        }
    }

    func canDelete(_ task: FamilyTask) -> Bool {
        task.creatorID == actor.id || actor.role == .parent
    }

    private func isForAChild(_ task: FamilyTask) -> Bool {
        members.contains { $0.role == .child && task.assigneeIDs.contains($0.id) }
    }

    func canComplete(_ task: FamilyTask) -> Bool {
        task.assigneeIDs.contains(actor.id) || actor.role == .parent
    }

    var canManageShortcuts: Bool { actor.role != .child }
    var canManageMembers: Bool { actor.role == .parent }
    var canPay: Bool { actor.role == .parent }
}
