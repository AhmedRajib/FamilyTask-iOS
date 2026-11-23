import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var store: FamilyStore
    @EnvironmentObject private var router: Router
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @Namespace private var namespace
    @State private var appeared = false
    /// Which way the tasks slide when the day changes: later days come in from the right.
    @State private var forward = true

    private let calendar = Calendar.current

    private var week: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDay)?.start ?? selectedDay
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        let dayTasks = store.tasks(on: selectedDay)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    ScreenTitle(selectedDay.formatted(.dateTime.month(.wide)))
                        .contentTransition(.opacity)
                    Spacer()
                    weekButton("chevron.left", by: -7, label: "Previous week")
                    weekButton("chevron.right", by: 7, label: "Next week")
                }
                .padding(.top, 8)
                .reveal(appeared, order: 0, distance: -10)

                weekStrip

                HStack {
                    Text("\(DueFormat.dayName(selectedDay)) · \(dayTasks.count) \(dayTasks.count == 1 ? "task" : "tasks")")
                        .font(.system(size: 16, weight: .semibold))
                        .contentTransition(.numericText())
                    Spacer()
                    if !calendar.isDateInToday(selectedDay) {
                        Button("Today") { select(calendar.startOfDay(for: .now)) }
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .reveal(appeared, order: 8)

                Group {
                if dayTasks.isEmpty {
                    EmptyStateView(emoji: "🌤️", title: "Nothing planned", message: "No tasks due on this day.")
                        .reveal(appeared, order: 9)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(dayTasks.enumerated()), id: \.element.id) { index, task in
                            HStack(alignment: .top, spacing: 10) {
                                Text(task.isAllDay ? "All day" : task.dueDate!.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(Theme.ink3)
                                    .frame(width: 54, alignment: .leading)
                                    .padding(.top, 16)
                                TaskCard(task: task)
                                    .contentShape(Rectangle())
                                    .onTapGesture { router.push(.taskDetail(task.id)) }
                                    .accessibilityAddTraits(.isButton)
                            }
                            .transition(.opacity)
                            .reveal(appeared, order: 9 + index, distance: 24, step: 0.06)
                        }
                    }
                }
                }
                // A new day's list slides in from the side you moved towards.
                .id(selectedDay)
                .transition(.asymmetric(
                    insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                    removal: .opacity))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .animation(Theme.spring, value: selectedDay)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .startsEntrance($appeared, isActive: router.tab == .calendar)
        .navigationTitle("Calendar")
        .toolbar(.hidden, for: .navigationBar)
    }

    private var weekStrip: some View {
        HStack(spacing: 4) {
            ForEach(Array(week.enumerated()), id: \.element) { index, day in
                let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
                let isToday = calendar.isDateInToday(day)
                let priorities = Array(store.tasks(on: day).filter { !$0.isDone }.map(\.priority).prefix(3))
                Button {
                    select(day)
                } label: {
                    VStack(spacing: 3) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isSelected ? .white.opacity(0.7) : Theme.ink3)
                        Text(day.formatted(.dateTime.day()))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(isSelected ? .white : (isToday ? Theme.urgent : Theme.ink))
                        HStack(spacing: 2) {
                            ForEach(Array(priorities.enumerated()), id: \.offset) { _, priority in
                                Circle()
                                    .fill(isSelected ? .white : priority.color)
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .frame(height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.ink)
                                .matchedGeometryEffect(id: "day", in: namespace)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .reveal(appeared, order: 1 + index, distance: 12, step: 0.04)
            }
        }
        .haptic(.selection, trigger: selectedDay)
    }

    private func weekButton(_ icon: String, by days: Int, label: String) -> some View {
        IconButton(systemImage: icon, label: label) {
            select(calendar.date(byAdding: .day, value: days, to: selectedDay) ?? selectedDay)
        }
    }

    private func select(_ day: Date) {
        guard day != selectedDay else { return }
        forward = day > selectedDay
        withAnimation(Theme.spring) { selectedDay = day }
    }
}

#Preview {
    NavigationStack { CalendarView() }.previewEnvironment()
}
