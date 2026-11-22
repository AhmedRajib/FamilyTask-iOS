import Foundation

/// Friendly due-date wording: "Today · 3:30 PM", "Tomorrow", "Tue · 10:00 AM".
enum DueFormat {
    static func dayName(_ date: Date, now: Date = .now) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)
        ).day ?? 99
        if (0..<7).contains(days) { return date.formatted(.dateTime.weekday(.abbreviated)) }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    static func describe(_ date: Date, allDay: Bool, now: Date = .now) -> String {
        let day = dayName(date, now: now)
        return allDay ? day : "\(day) · \(date.formatted(date: .omitted, time: .shortened))"
    }

    static func short(_ task: FamilyTask, now: Date = .now) -> String? {
        task.dueDate.map { describe($0, allDay: task.isAllDay, now: now) }
    }

    static func isOverdue(_ task: FamilyTask, now: Date = .now) -> Bool {
        guard task.status == .open, let due = task.dueDate else { return false }
        if task.isAllDay {
            let calendar = Calendar.current
            return calendar.startOfDay(for: due) < calendar.startOfDay(for: now)
        }
        return due < now
    }

    /// "in 2h 15m", "in 25m", "in 3 days".
    static func countdown(to date: Date, now: Date = .now) -> String {
        let minutes = Int(date.timeIntervalSince(now) / 60)
        guard minutes > 0 else { return "now" }
        if minutes < 60 { return "in \(minutes)m" }
        if minutes < 24 * 60 {
            let h = minutes / 60, m = minutes % 60
            return m == 0 ? "in \(h)h" : "in \(h)h \(m)m"
        }
        let days = minutes / (24 * 60)
        return days == 1 ? "in 1 day" : "in \(days) days"
    }
}
