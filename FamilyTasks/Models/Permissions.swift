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
/// - The creator (or a parent) can edit and delete; assignees can complete or decline.
struct Permissions {
    let actor: Member

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
        actor.role == .parent || task.creatorID == actor.id
    }

    func canDelete(_ task: FamilyTask) -> Bool { canEdit(task) }

    func canComplete(_ task: FamilyTask) -> Bool {
        task.assigneeIDs.contains(actor.id) || actor.role == .parent
    }

    var canManageShortcuts: Bool { actor.role != .child }
    var canManageMembers: Bool { actor.role == .parent }
    var canPay: Bool { actor.role == .parent }
}
