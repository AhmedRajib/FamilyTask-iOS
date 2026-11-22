import SwiftUI

/// "When?" — two plain questions: Which day? What time?
/// The calendar and time wheel only open when asked for.
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
    @State private var exactTime = Date.now
    @State private var showCalendar = false
    @State private var showWheel = false
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
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                        ForEach(times) { shortcut in
                            let passed = shortcut.date(on: selectedDay) < .now
                            tile(emoji: shortcut.emoji, title: shortcut.name,
                                 detail: passed ? "Passed" : shortcut.timeText,
                                 isOn: time == .shortcut(shortcut.id)) {
                                time = .shortcut(shortcut.id)
                                showWheel = false
                            }
                            .disabled(passed)
                            .opacity(passed ? 0.4 : 1)
                        }
                        tile(emoji: "🕐", title: "Exact time…",
                             detail: time == .exact ? exactTime.formatted(date: .omitted, time: .shortened) : "Choose",
                             isOn: time == .exact) {
                            time = .exact
                            showWheel.toggle()
                        }
                        tile(emoji: "☀️", title: "Any time", detail: "No set time", isOn: time == .anyTime) {
                            time = .anyTime
                            showWheel = false
                        }
                    }
                    if showWheel {
                        DatePicker("Time", selection: $exactTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .card(padding: 0)
                            .padding(.top, 8)
                            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                    }
                }
                .padding(20)
                .animation(Theme.spring, value: showCalendar)
                .animation(Theme.spring, value: showWheel)
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
                time = .shortcut(next.id)
            } else {
                day = .tomorrow
                time = times.first.map { .shortcut($0.id) } ?? .anyTime
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
            let parts = calendar.dateComponents([.hour, .minute], from: current)
            if let match = times.first(where: { $0.hour == parts.hour && $0.minute == parts.minute }) {
                time = .shortcut(match.id)
            } else {
                time = .exact
                exactTime = current
            }
        }
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

    private func tile(emoji: String, title: String, detail: String, isOn: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(emoji).font(.system(size: 22))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 14, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.85)
                    Text(detail).font(.system(size: 12)).foregroundStyle(isOn ? .white.opacity(0.75) : Theme.ink2)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(isOn ? .white : Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(isOn ? Theme.ink : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isOn ? Theme.ink : Theme.line, lineWidth: 1.5))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        WhenPickerSheet(dueDate: .constant(nil), isAllDay: .constant(false), times: SampleData.make().family.times)
    }
}
