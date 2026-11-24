import SwiftUI

// MARK: - Family & members

enum Role: String, Codable, CaseIterable {
    case parent, adult, child

    var title: String {
        switch self {
        case .parent: "Parent"
        case .adult: "Adult"
        case .child: "Child"
        }
    }

    var badge: String {
        switch self {
        case .parent: "👑 Parent"
        case .adult: "Adult"
        case .child: "Child"
        }
    }

    var emoji: String {
        switch self {
        case .parent: "👑"
        case .adult: "🧑"
        case .child: "🧒"
        }
    }

    var blurb: String {
        switch self {
        case .parent: "Full control"
        case .adult: "Grandparent, teen, helper"
        case .child: "Asks, earns stars"
        }
    }
}

/// A phone or iPad signed in as a member. Shows only a name and date — never location or activity.
struct Device: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var signedInAt: Date
}

/// A one-time code that signs a device in as a specific member. The role comes from the member.
struct Invite: Codable, Hashable {
    var code: String
    var expiresAt: Date

    var isExpired: Bool { expiresAt < .now }
}

struct Member: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var role: Role
    var colorHex: UInt32
    /// Apple / email login. Children usually have none: their invite code signs the device in.
    var accountID: String? = nil
    var devices: [Device] = []
    var invite: Invite? = nil

    var initial: String { String(name.prefix(1)).uppercased() }
    var color: Color { Color(hex: colorHex) }

    /// Added by a parent but not yet joined on any device.
    var isInvited: Bool { accountID == nil && devices.isEmpty }

    static let palette: [UInt32] = [0x3D7BD9, 0xE86A92, 0x9B6DD8, 0x2E9E6B, 0xE08A3C, 0x14A3B8]
}

/// How someone signed in on this device.
struct Account: Codable, Hashable {
    enum Provider: String, Codable { case apple, email, demo }

    var id: String
    var name: String
    var email: String?
    var provider: Provider
}

struct Family: Identifiable, Codable {
    var id = UUID()
    var name: String
    var members: [Member]
    var places: [Place]
    var times: [TimeShortcut]
    var templates: [TaskTemplate]
    /// One subscription covers the whole family. Optional so older saved data still loads.
    var premium: PremiumStatus? = nil
    /// "Ali would like Stars & rewards" — shown to parents in the Inbox.
    var premiumRequests: [PremiumRequest]? = nil
    /// Children asking for new family places. Optional so older saved data still loads.
    var placeRequests: [PlaceRequest]? = nil
}

// MARK: - Premium

struct PremiumStatus: Codable, Hashable {
    var productID: String
    var expiresAt: Date
    var isTrial: Bool
    /// The parent who subscribed.
    var purchasedBy: UUID

    var isActive: Bool { expiresAt > .now }
}

/// A child found a place on the map and asked for it to become a family place.
/// Private to the child and the parents/adults until someone approves it.
struct PlaceRequest: Identifiable, Codable, Hashable {
    enum Status: String, Codable { case pending, approved, declined }

    var id = UUID()
    var memberID: UUID
    /// Where the child put the pin, with the name and emoji they chose.
    var place: Place
    var hint: String = ""
    /// The task they were making, so parents know why ("for Swimming lesson").
    var forTaskTitle: String? = nil
    var date: Date = .now
    var status: Status = .pending
    var decidedBy: UUID? = nil
    var decidedAt: Date? = nil
    /// The family place it became (the parent may have edited it).
    var approvedPlaceID: UUID? = nil
    /// The child has seen the outcome and cleared it from their Inbox.
    var isDismissed = false
}

struct PremiumRequest: Identifiable, Codable, Hashable {
    var id = UUID()
    var memberID: UUID
    var feature: PremiumFeature
    var date: Date = .now
}

/// What Premium unlocks. `isAvailable` is false for features still being built —
/// they're shown as "Soon" so the paywall never promises something that isn't there.
enum PremiumFeature: String, Codable, CaseIterable, Identifiable {
    case locationReminders, customSounds, urgentRing, starsRewards

    var id: Self { self }

    var emoji: String {
        switch self {
        case .locationReminders: "📍"
        case .customSounds: "🎵"
        case .urgentRing: "📞"
        case .starsRewards: "⭐"
        }
    }

    var title: String {
        switch self {
        case .locationReminders: "Unlimited location reminders"
        case .customSounds: "Your own sounds"
        case .urgentRing: "Urgent tasks ring like a call"
        case .starsRewards: "Stars & rewards for kids"
        }
    }

    var shortTitle: String {
        switch self {
        case .locationReminders: "Location reminders"
        case .customSounds: "Your own sounds"
        case .urgentRing: "Urgent ring"
        case .starsRewards: "Stars & rewards"
        }
    }

    var blurb: String {
        switch self {
        case .locationReminders: "Free families can have \(PremiumFeature.freeLocationReminders) location reminders at a time. Premium removes the limit."
        case .customSounds: "Use any sound from your phone, like a voice note from Mum, for reminders and urgent tasks."
        case .urgentRing: "Urgent tasks ring full-screen until someone answers."
        case .starsRewards: "Earn stars for every chore and swap them for rewards your parents choose."
        }
    }

    var isAvailable: Bool {
        switch self {
        case .locationReminders, .customSounds: true
        case .urgentRing, .starsRewards: false
        }
    }

    static let freeLocationReminders = 2
}

// MARK: - Shortcuts

/// A saved family place (Home, School, FreshMart). Location reminders point at one of these.
struct Place: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var emoji: String
    var address: String
    var latitude: Double
    var longitude: Double
    var radius: Double

    var radiusText: String {
        radius >= 1000 ? String(format: "%.1f km", radius / 1000) : "\(Int(radius)) m"
    }
}

/// A saved family time (Before school 7:30, After school 3:30).
struct TimeShortcut: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var emoji: String
    var hour: Int
    var minute: Int

    func date(on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    /// Today at this time, or tomorrow if that has already passed.
    func nextOccurrence(after now: Date = .now, calendar: Calendar = .current) -> Date {
        let today = date(on: now, calendar: calendar)
        if today > now { return today }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return date(on: tomorrow, calendar: calendar)
    }

    var timeText: String {
        date(on: .now).formatted(date: .omitted, time: .shortened)
    }
}

/// A one-tap quick task (School pickup, Weekly groceries).
struct TaskTemplate: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var emoji: String
    var priority: Priority
    var timeShortcutID: UUID?
    var repeatRule: RepeatRule
    var placeID: UUID?
    var checklist: [String]
}

// MARK: - Task

enum Priority: String, Codable, CaseIterable, Identifiable {
    case low, normal, high, urgent

    var id: Self { self }
    var title: String { rawValue.capitalized }

    var rank: Int {
        switch self {
        case .low: 0
        case .normal: 1
        case .high: 2
        case .urgent: 3
        }
    }

    var color: Color {
        switch self {
        case .low: Theme.low
        case .normal: Theme.brand
        case .high: Theme.high
        case .urgent: Theme.urgent
        }
    }

    var softColor: Color {
        switch self {
        case .low: Theme.lowSoft
        case .normal: Theme.brandSoft
        case .high: Theme.highSoft
        case .urgent: Theme.urgentSoft
        }
    }

    /// Readable text colour on `softColor`.
    var textColor: Color { self == .high ? Theme.highText : color }
}

enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case never, daily, weekdays, weekly

    var id: Self { self }

    var title: String {
        switch self {
        case .never: "Never"
        case .daily: "Daily"
        case .weekdays: "Weekdays"
        case .weekly: "Weekly"
        }
    }

    /// The next due date after `date`, or nil for `.never`.
    func next(after date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .never:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .weekdays:
            var day = date
            repeat {
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
                day = next
            } while calendar.isDateInWeekend(day)
            return day
        }
    }
}

enum ReminderOption: Int, Codable, CaseIterable, Identifiable {
    case none = -1
    case atTime = 0
    case tenMinutes = 10
    case thirtyMinutes = 30
    case oneHour = 60

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .atTime: "At due time"
        case .tenMinutes: "10 min before"
        case .thirtyMinutes: "30 min before"
        case .oneHour: "1 hour before"
        }
    }
}

enum PlaceTrigger: String, Codable, CaseIterable {
    case arriving, leaving

    var title: String { self == .arriving ? "Arriving" : "Leaving" }
}

/// Fires only on the assignee's phone. Never reported to the server or to anyone else.
/// Points at a saved family place (`placeID`) or carries its own one-off place (`custom`).
struct LocationReminder: Codable, Hashable {
    /// A family place from Shortcuts. Optional so a task can use a one-off place instead.
    var placeID: UUID? = nil
    /// Somewhere only this task uses (a dentist, a friend's house). Not listed in Shortcuts.
    var custom: Place? = nil
    var trigger: PlaceTrigger
}

struct ChecklistItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var isDone = false
}

enum TaskStatus: String, Codable {
    /// A child asked an adult; waiting for Accept / Can't do it.
    case requested
    case open
    case declined
    case done
}

struct FamilyTask: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var notes: String = ""
    var creatorID: UUID
    var assigneeIDs: [UUID]
    var priority: Priority = .normal
    var dueDate: Date? = nil
    /// Due on `dueDate`'s day with no set time.
    var isAllDay: Bool = false
    var repeatRule: RepeatRule = .never
    var reminder: ReminderOption = .none
    var location: LocationReminder? = nil
    var checklist: [ChecklistItem] = []
    /// Only the creator can see it. Only allowed when the creator is the sole assignee.
    var isPrivate: Bool = false
    var status: TaskStatus = .open
    var declineReason: String? = nil
    var completedByID: UUID? = nil
    var completedAt: Date? = nil
    /// The repeat copy created when this was completed, removed again if it's reopened.
    var nextOccurrenceID: UUID? = nil
    var createdAt: Date = .now
    /// Who last changed the task after it was created, so the creator can be told.
    var editedByID: UUID? = nil
    var editedAt: Date? = nil

    var isDone: Bool { status == .done }
}
