import AVFoundation
import AudioToolbox
import Combine
import UserNotifications
import UIKit

/// This phone's sound choices. Sounds are personal, so they're saved per device, not synced.
final class SoundSettings: ObservableObject {
    static let shared = SoundSettings()

    @Published var notificationToneID: String { didSet { save() } }
    @Published var ringtoneID: String { didSet { save() } }
    @Published var vibrate: Bool { didSet { save() } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        notificationToneID = defaults.string(forKey: "sound.notification") ?? "Chime"
        ringtoneID = defaults.string(forKey: "sound.ringtone") ?? "Classic"
        vibrate = defaults.object(forKey: "sound.vibrate") as? Bool ?? true
    }

    func selected(_ kind: ToneKind) -> String {
        kind == .notification ? notificationToneID : ringtoneID
    }

    func select(_ id: String, for kind: ToneKind) {
        if kind == .notification { notificationToneID = id } else { ringtoneID = id }
    }

    /// If a deleted sound was in use, go back to the default.
    func toneDeleted(_ id: String) {
        if notificationToneID == id { notificationToneID = "Chime" }
        if ringtoneID == id { ringtoneID = "Classic" }
    }

    private func save() {
        defaults.set(notificationToneID, forKey: "sound.notification")
        defaults.set(ringtoneID, forKey: "sound.ringtone")
        defaults.set(vibrate, forKey: "sound.vibrate")
    }
}

/// Plays a tone inside the app so people can hear it before choosing it.
final class TonePreviewPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var playingID: String?
    private var player: AVAudioPlayer?

    func toggle(_ id: String) {
        if playingID == id { stop() } else { play(id) }
    }

    func play(_ id: String) {
        stop()
        if id == ToneLibrary.silentID { return }
        guard let url = ToneLibrary.fileURL(for: id) else {
            // "iPhone default": the standard tri-tone.
            AudioServicesPlaySystemSound(1007)
            return
        }
        do {
            // Play even when the ring/silent switch is on silent, so the preview is always heard.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.play()
            self.player = player
            playingID = id
        } catch {
            playingID = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.playingID = nil }
    }
}

/// Local notifications. For now: permission and test notifications with the chosen sounds.
/// Real task reminders will use the same sounds when they're added.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    /// Asks for permission if not asked yet. Returns whether notifications are allowed.
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    /// Sends a sample notification a few seconds from now, using this phone's chosen sound.
    func sendTest(_ kind: ToneKind, settings: SoundSettings, after seconds: TimeInterval = 3) async -> Bool {
        guard await requestPermission() else { return false }
        let content = UNMutableNotificationContent()
        if kind == .ringtone {
            content.title = "⚡ Urgent from Nadia"
            content.body = "Pick up Ali from school — today 3:30 PM"
        } else {
            content.title = "Reminder"
            content.body = "Pay electricity bill — due at 6:00 PM"
        }
        content.sound = ToneLibrary.notificationSound(for: settings.selected(kind))
        let request = UNNotificationRequest(
            identifier: "test-\(kind.rawValue)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
    }

    /// Show notifications (with sound) even while the app is open.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
