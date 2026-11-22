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

    func push(_ route: Route) {
        paths[tab, default: []].append(route)
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
