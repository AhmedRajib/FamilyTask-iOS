import Foundation

/// A family, its tasks, and who is looking at it.
struct Snapshot {
    var family: Family
    var tasks: [FamilyTask]
    var currentMemberID: UUID
}

/// Demo family used on first launch until accounts and server sync exist.
enum SampleData {
    static func make(now: Date = .now) -> Snapshot {
        let calendar = Calendar.current
        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        let joined = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        func phone(_ name: String) -> [Device] { [Device(id: UUID(), name: name, signedInAt: joined)] }

        let rajib = Member(name: "Rajib", role: .parent, colorHex: 0x3D7BD9,
                           accountID: LocalServer.demoAccount.id, devices: phone("Rajib's iPhone"))
        let nadia = Member(name: "Nadia", role: .parent, colorHex: 0xE86A92,
                           accountID: "demo-nadia", devices: phone("Nadia's iPhone"))
        let sara = Member(name: "Sara", role: .adult, colorHex: 0x9B6DD8,
                          accountID: "demo-sara", devices: phone("Sara's Pixel"))
        let ali = Member(name: "Ali", role: .child, colorHex: 0x2E9E6B, devices: phone("Ali's iPhone"))
        // Not joined yet — use code NANA-2026 on the Join screen to try joining.
        let nana = Member(name: "Nana", role: .adult, colorHex: 0xE08A3C,
                          invite: Invite(code: LocalServer.demoInviteCode,
                                         expiresAt: calendar.date(byAdding: .year, value: 5, to: now) ?? now))

        // Coordinates near the simulator's default location, for testing geofences later.
        let home = Place(name: "Home", emoji: "🏠", address: "12 Elm Street", latitude: 37.3349, longitude: -122.0090, radius: 100)
        let school = Place(name: "School", emoji: "🏫", address: "Oakfield School", latitude: 37.3318, longitude: -122.0312, radius: 150)
        let shop = Place(name: "FreshMart", emoji: "🛒", address: "Elm Street branch", latitude: 37.3230, longitude: -122.0322, radius: 150)
        let clinic = Place(name: "Clinic", emoji: "🏥", address: "City Clinic", latitude: 37.3387, longitude: -122.0410, radius: 120)

        let beforeSchool = TimeShortcut(name: "Before school", emoji: "🎒", hour: 7, minute: 30)
        let afterSchool = TimeShortcut(name: "After school", emoji: "🏫", hour: 15, minute: 30)
        let dinner = TimeShortcut(name: "Dinner", emoji: "🍽️", hour: 19, minute: 0)
        let bedtime = TimeShortcut(name: "Bedtime", emoji: "🌙", hour: 21, minute: 0)

        let templates = [
            TaskTemplate(title: "School pickup", emoji: "🏫", priority: .high, timeShortcutID: afterSchool.id,
                         repeatRule: .weekdays, placeID: school.id, checklist: []),
            TaskTemplate(title: "Weekly groceries", emoji: "🛒", priority: .normal, timeShortcutID: nil,
                         repeatRule: .weekly, placeID: shop.id, checklist: ["Rice", "Milk", "Eggs", "Bread", "Bananas"]),
            TaskTemplate(title: "Nana's medicine", emoji: "💊", priority: .urgent, timeShortcutID: bedtime.id,
                         repeatRule: .daily, placeID: nil, checklist: []),
        ]

        let tasks: [FamilyTask] = [
            FamilyTask(
                title: "Pick up Ali from school", notes: "Gate 2 — he has football kit today",
                creatorID: nadia.id, assigneeIDs: [rajib.id], priority: .urgent, dueDate: at(0, 15, 30),
                reminder: .thirtyMinutes, location: LocationReminder(placeID: school.id, trigger: .arriving),
                checklist: [
                    ChecklistItem(title: "Grab football kit from car", isDone: true),
                    ChecklistItem(title: "Sign attendance sheet"),
                    ChecklistItem(title: "Get snacks on the way"),
                ]
            ),
            FamilyTask(
                title: "Pay electricity bill", creatorID: nadia.id, assigneeIDs: [rajib.id],
                priority: .high, dueDate: at(0, 18, 0), reminder: .thirtyMinutes
            ),
            FamilyTask(
                title: "Groceries for the week", creatorID: rajib.id, assigneeIDs: [rajib.id, sara.id],
                dueDate: at(1, 10, 0), location: LocationReminder(placeID: shop.id, trigger: .arriving),
                checklist: [
                    ChecklistItem(title: "Rice 5 kg", isDone: true),
                    ChecklistItem(title: "Oat milk ×2", isDone: true),
                    ChecklistItem(title: "Eggs"),
                    ChecklistItem(title: "Bread"),
                    ChecklistItem(title: "Bananas"),
                ]
            ),
            FamilyTask(
                title: "Water the plants", creatorID: rajib.id, assigneeIDs: [rajib.id], priority: .low,
                dueDate: at(0, 8, 0), status: .done, completedByID: rajib.id, completedAt: at(0, 8, 10)
            ),
            FamilyTask(
                title: "Feed the cat", creatorID: nadia.id, assigneeIDs: [ali.id],
                dueDate: at(0, 10, 0), repeatRule: .daily
            ),
            FamilyTask(
                title: "Homework check", creatorID: nadia.id, assigneeIDs: [sara.id], dueDate: at(0, 17, 0)
            ),
            FamilyTask(
                title: "Blood pressure tablet", creatorID: nadia.id, assigneeIDs: [nana.id], priority: .urgent,
                dueDate: at(0, 21, 0), repeatRule: .daily, reminder: .tenMinutes
            ),
            FamilyTask(
                title: "Buy new football boots", notes: "Size 4 — mine are torn 🙏",
                creatorID: ali.id, assigneeIDs: [rajib.id], dueDate: at(3, 0, 0), isAllDay: true, status: .requested
            ),
            FamilyTask(
                title: "Tidy your room", creatorID: rajib.id, assigneeIDs: [ali.id],
                dueDate: at(0, 12, 0), status: .done, completedByID: ali.id, completedAt: at(0, 11, 40)
            ),
            FamilyTask(
                title: "Book dentist for Sara", creatorID: nadia.id, assigneeIDs: [rajib.id, nadia.id],
                dueDate: at(4, 0, 0), isAllDay: true
            ),
        ]

        let family = Family(
            name: "The Ahmed Home",
            members: [rajib, nadia, sara, ali, nana],
            places: [home, school, shop, clinic],
            times: [beforeSchool, afterSchool, dinner, bedtime],
            templates: templates
        )
        return Snapshot(family: family, tasks: tasks, currentMemberID: rajib.id)
    }
}
