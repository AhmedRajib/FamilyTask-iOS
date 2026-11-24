import SwiftUI
import Combine

enum AppTab: CaseIterable {
    case home, calendar, family, inbox

    var title: String {
        switch self {
        case .home: "Home"
        case .calendar: "Calendar"
        case .family: "Family"
        case .inbox: "Inbox"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .calendar: "calendar"
        case .family: "person.2"
        case .inbox: "tray"
        }
    }

    var selectedIcon: String {
        switch self {
        case .calendar: "calendar"
        default: icon + ".fill"
        }
    }
}

/// Pushed screens. New Task is a full page, like a navigation controller push.
enum Route: Hashable {
    case newTask(templateID: UUID?)
    case taskDetail(UUID)
    case shortcuts
    /// nil = new. Add / edit pages for family shortcuts.
    case editTemplate(UUID?)
    case editPlace(UUID?)
    case editTime(UUID?)
    /// A parent checks a child's place request (pre-filled New place).
    case reviewPlaceRequest(UUID)
    case addMember
    case invite(memberID: UUID)
    case memberProfile(UUID)
    case search
    case sounds
    case tonePicker(ToneKind)
}

/// Each tab keeps its own navigation stack.
final class Router: ObservableObject {
    @Published var tab: AppTab = .home
    @Published private var paths: [AppTab: [Route]] = [:]

    func path(for tab: AppTab) -> Binding<[Route]> {
        Binding(
            get: { self.paths[tab] ?? [] },
            set: { self.paths[tab] = $0 }
        )
    }

    // MARK: Tablet

    /// Set by MainTabsView from the window width.
    var layout: LayoutClass = .compact
    /// Expanded layout: the task shown in the detail pane, per tab (Home, Inbox).
    @Published var selectedTask: [AppTab: UUID] = [:]
    /// Expanded layout: the member profile shown next to the Family list.
    @Published var selectedMember: UUID?
    /// Sidebar "People": shows only this person's tasks on Home (same as the phone's face strip).
    @Published var homeMemberFilter: UUID?
    /// Tablet New Task opens as a centred two-column sheet instead of a full-screen push.
    @Published var newTask: NewTaskRequest?

    struct NewTaskRequest: Identifiable, Equatable {
        let id = UUID()
        let templateID: UUID?
    }

    func push(_ route: Route) {
        if layout.isTablet, case .newTask(let templateID) = route {
            newTask = NewTaskRequest(templateID: templateID)
            return
        }
        if layout == .expanded {
            switch (route, tab) {
            case (.taskDetail(let id), .home), (.taskDetail(let id), .inbox):
                selectedTask[tab] = id
                return
            case (.memberProfile(let id), .family) where isAtRoot:
                selectedMember = id
                return
            default: break
            }
        }
        paths[tab, default: []].append(route)
    }

    /// Back from the detail pane, or after deleting the task it shows.
    func clearSelection() {
        selectedTask[tab] = nil
    }

    /// Swaps the current page for another (Add member → Invite), so Back skips the form.
    func replaceTop(with route: Route) {
        var path = paths[tab] ?? []
        if !path.isEmpty { path.removeLast() }
        path.append(route)
        paths[tab] = path
    }

    var isAtRoot: Bool { (paths[tab] ?? []).isEmpty }
}
