import SwiftUI
import UserNotifications

@main
struct FamilyTasksApp: App {
    @StateObject private var session = AppSession()

    init() {
        // Lets notifications show (with their sound) while the app is open.
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                // The palette is designed for light mode; dark mode comes later.
                .preferredColorScheme(.light)
                .tint(Theme.brand)
        }
    }
}
