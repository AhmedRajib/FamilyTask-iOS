import SwiftUI

/// "When?" — two plain questions: Which day? What time?
/// Family times are one row of chips; a custom time row is always on screen.
struct WhenPickerSheet: View {
    @Binding var dueDate: Date?
    @Binding var isAllDay: Bool
    let times: [TimeShortcut]
    @Environment(\.dismiss) private var dismiss

    private enum DayChoice: Hashable { case today, tomorrow, weekend, other }
    private enum TimeChoice: Hashable { case shortcut(UUID), exact, anyTime }

    @State private var day: DayChoice = .today
    @State private var otherDay = Date.now
    @State private var time: TimeChoice = .anyTime
    @State private var exactTime = Self.nextQuarterHour()
    @State private var showCalendar = false
    @State private var didLoad = false

    private let calendar = Calendar.current
    private var today: Date { calendar.startOfDay(for: .now) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    preview

                    question("Which day?")
                    VStack(spacing: 6) {
                        dayRow(.today, "Today", detail: shortDate(today))
                        dayRow(.tomorrow, "Tomorrow", detail: shortDate(date(for: .tomorrow)))
                        dayRow(.weekend, "This weekend", detail: shortDate(date(for: .weekend)))
                        dayRow(.other, "Another day…", detail: day == .other ? shortDate(otherDay) : "",
                               icon: "calendar")
                    }
                    if showCalendar {
                        DatePicker("Day", selection: $otherDay, in: today..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .tint(Theme.ink)
                            .card(padding: 8)
                            .padding(.top, 8)
                            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                    }

                    question("What time?")
                    timeChips
                    customTimeRow
                        .padding(.top, 10)
                }
                .padding(20)
                .animation(Theme.spring, value: showCalendar)
                .animation(.quick(0.25), value: day)
                .animation(.quick(0.25), value: time)
            }
            .background(Theme.background)
            .navigationTitle("When?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if dueDate != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("No date", role: .destructive) {
                            dueDate = nil
                            isAllDay = false
                            dismiss()
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button("Save · \(summary)") {
                    dueDate = resolved
                    isAllDay = time == .anyTime
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isPast)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Theme.background)
            }
            .haptic(.selection, trigger: day)
            .haptic(.selection, trigger: time)
        }
        .presentationDetents([.large])
        .sheetCornerRadius(26)
        .onAppear(perform: load)
    }

    // MARK: - Preview card

    private var preview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary)
                .font(.system(size: 24, weight: .bold))
                .contentTransition(.numericText())
            Text(isPast ? "That time has already passed" : detailLine)
                .font(.system(size: 13))
                .opacity(0.75)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(isPast ? Theme.urgent : Theme.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(Theme.spring, value: summary)
        .accessibilityElement(children: .combine)
    }

    private var summary: String {
        let dayText = DueFormat.dayName(selectedDay)
        switch time {
        case .anyTime: return "\(dayText) · Any time"
        default: return "\(dayText) · \(resolved.formatted(date: .omitted, time: .shortened))"
        }
    }

    private var detailLine: String {
        let full = selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide))
        guard time != .anyTime else { return full }
        return "\(full) · \(DueFormat.countdown(to: resolved))"
    }

    // MARK: - Resolving the choice

    private func date(for choice: DayChoice) -> Date {
        switch choice {
        case .today: return today
        case .tomorrow: return calendar.date(byAdding: .day, value: 1, to: today) ?? today
        case .weekend:
            if calendar.component(.weekday, from: today) == 7 { return today } // already Saturday
            return calendar.nextDate(after: today, matching: DateComponents(weekday: 7), matchingPolicy: .nextTime) ?? today
        case .other: return calendar.startOfDay(for: otherDay)
        }
    }

    private var selectedDay: Date { date(for: day) }

    private var resolved: Date {
        switch time {
        case .anyTime:
            return selectedDay
        case .shortcut(let id):
            return times.first { $0.id == id }?.date(on: selectedDay) ?? selectedDay
        case .exact:
            let parts = calendar.dateComponents([.hour, .minute], from: exactTime)
            return calendar.date(bySettingHour: parts.hour ?? 9, minute: parts.minute ?? 0, second: 0, of: selectedDay) ?? selectedDay
        }
    }

    private var isPast: Bool {
        time == .anyTime ? selectedDay < today : resolved < .now
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// Start from the task's current date, or today at the next family time.
    private func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let current = dueDate else {
            day = .today
            if let next = times.first(where: { $0.date(on: today) > .now }) {
                pick(next)
            } else if let first = times.first {
                day = .tomorrow
                pick(first)
            } else {
                time = .exact
            }
            return
        }
        let start = calendar.startOfDay(for: current)
        if start == today { day = .today }
        else if start == date(for: .tomorrow) { day = .tomorrow }
        else if start == date(for: .weekend) { day = .weekend }
        else { day = .other; otherDay = start; showCalendar = true }

        if isAllDay {
            time = .anyTime
        } else {
            setExact(current)
        }
    }

    /// Next 15-minute slot, so a fresh custom time is never already in the past.
    private static func nextQuarterHour(from date: Date = .now, calendar: Calendar = .current) -> Date {
        let minute = calendar.component(.minute, from: date)
        let bumped = calendar.date(byAdding: .minute, value: 15 - minute % 15, to: date) ?? date
        return calendar.date(bySetting: .second, value: 0, of: bumped) ?? bumped
    }

    private func pick(_ shortcut: TimeShortcut) {
        time = .shortcut(shortcut.id)
        exactTime = shortcut.date(on: selectedDay)
    }

    /// Any edit to the custom time selects it, or lights up the family time it matches.
    private func setExact(_ date: Date) {
        exactTime = date
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        if let match = times.first(where: { $0.hour == parts.hour && $0.minute == parts.minute }) {
            time = .shortcut(match.id)
        } else {
            time = .exact
        }
    }

    private func nudge(minutes: Int) {
        setExact(calendar.date(byAdding: .minute, value: minutes, to: exactTime) ?? exactTime)
    }

    private var exactBinding: Binding<Date> {
        Binding(get: { exactTime }, set: { setExact($0) })
    }

    // MARK: - Building blocks

    private func question(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Theme.ink)
            .padding(.top, 22)
            .padding(.bottom, 10)
            .accessibilityAddTraits(.isHeader)
    }

    private func dayRow(_ choice: DayChoice, _ title: String, detail: String, icon: String? = nil) -> some View {
        let isOn = day == choice
        return Button {
            if choice == .other && day == .other {
                showCalendar.toggle()
            } else {
                day = choice
                showCalendar = choice == .other
            }
        } label: {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 17)).foregroundStyle(Theme.ink2).frame(width: 20)
                } else {
                    Circle()
                        .strokeBorder(isOn ? Theme.ink : Theme.line, lineWidth: isOn ? 6 : 2)
                        .frame(width: 20, height: 20)
                }
                Text(title).font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(detail).font(.system(size: 13)).foregroundStyle(Theme.ink3)
                if icon != nil {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                        .rotationEffect(.degrees(showCalendar ? 180 : 0))
                }
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(isOn ? Theme.surface2 : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isOn ? Theme.ink : Theme.line, lineWidth: 1.5))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// Family times that haven't passed on the chosen day, then "Any time".
    private var timeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(times.filter { $0.date(on: selectedDay) > .now }) { shortcut in
                    chip("\(shortcut.emoji) \(shortcut.timeText)", isOn: time == .shortcut(shortcut.id)) {
                        pick(shortcut)
                    }
                    .accessibilityLabel("\(shortcut.name), \(shortcut.timeText)")
                }
                chip("☀️ Any time", isOn: time == .anyTime) { time = .anyTime }
                    .accessibilityHint("No set time")
            }
            .padding(.vertical, 1)
        }
    }

    private func chip(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isOn ? .white : Theme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isOn ? Theme.ink : Theme.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(isOn ? Theme.ink : Theme.line, lineWidth: 1.5))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// Always on screen: tap the time for the iOS picker, or nudge it.
    private var customTimeRow: some View {
        let isOn = time == .exact
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "clock")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.brand)
                Text("Custom time")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                DatePicker("Custom time", selection: exactBinding, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Theme.brand)
            }
            HStack(spacing: 6) {
                nudgeButton("−15m", minutes: -15, spoken: "15 minutes earlier")
                nudgeButton("+15m", minutes: 15, spoken: "15 minutes later")
                nudgeButton("+1h", minutes: 60, spoken: "1 hour later")
            }
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(isOn ? Theme.ink : Theme.line, lineWidth: 1.5))
        .opacity(time == .anyTime ? 0.6 : 1)
    }

    private func nudgeButton(_ label: String, minutes: Int, spoken: String) -> some View {
        Button(label) { nudge(minutes: minutes) }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.ink2)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Theme.surface2, in: Capsule())
            .buttonStyle(PressableStyle())
            .accessibilityLabel(spoken)
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        WhenPickerSheet(dueDate: .constant(nil), isAllDay: .constant(false), times: SampleData.make().family.times)
    }
}
