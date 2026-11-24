import SwiftUI

/// The Calendar tab: the phone's day list, or the tablet time grid (T4).
struct CalendarScreen: View {
    @Environment(\.layoutClass) private var layout

    var body: some View {
        if layout.isTablet { CalendarWeekView() } else { CalendarView() }
    }
}

/// T4 · Family calendar on a tablet. Week (7 days; 3 days in medium width), Day or Month,
/// with person chips that toggle people on and off. Today's column is tinted, with a red now-line.
struct CalendarWeekView: View {
    @EnvironmentObject private var store: FamilyStore
    @EnvironmentObject private var router: Router
    @Environment(\.layoutClass) private var layout

    enum Mode: String, CaseIterable { case day = "Day", week = "Week", month = "Month" }

    @State private var mode: Mode = .week
    @State private var anchor = Calendar.current.startOfDay(for: .now)
    @State private var hidden: Set<UUID> = []

    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 56
    private let gutter: CGFloat = 52

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            personChips.padding(.top, 12).padding(.bottom, 12)
            Rectangle().fill(Theme.line).frame(height: 1)
            if mode == .month {
                monthGrid
            } else {
                timeGrid
            }
        }
        .padding(.horizontal, 20)
        .background(Theme.background)
        .navigationTitle("Calendar")
        .toolbar(.hidden, for: .navigationBar)
        .haptic(.selection, trigger: anchor)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(mode == .month ? anchor.formatted(.dateTime.year()) : "Week \(calendar.component(.weekOfYear, from: anchor))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.ink2)
                Text(anchor.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.opacity)
            }
            Spacer()
            PillSegmented(options: Mode.allCases, selection: $mode.animation(Theme.spring)) { $0.rawValue }
                .frame(width: 230)
            IconButton(systemImage: "chevron.left", label: "Previous") { move(-1) }
            Button("Today") {
                withAnimation(Theme.spring) { anchor = calendar.startOfDay(for: .now) }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line))
            IconButton(systemImage: "chevron.right", label: "Next") { move(1) }
        }
        .padding(.top, 12)
    }

    private func move(_ direction: Int) {
        let next: Date?
        switch mode {
        case .day: next = calendar.date(byAdding: .day, value: direction, to: anchor)
        case .week: next = calendar.date(byAdding: .day, value: direction * days.count, to: anchor)
        case .month: next = calendar.date(byAdding: .month, value: direction, to: anchor)
        }
        withAnimation(Theme.spring) { anchor = next ?? anchor }
    }

    private var personChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(store.family.members) { member in
                    let isOn = !hidden.contains(member.id)
                    Button {
                        withAnimation(.quick(0.2)) {
                            if isOn { hidden.insert(member.id) } else { hidden.remove(member.id) }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            AvatarView(member: member, size: 20)
                            Text(member.id == store.me.id ? "Me" : member.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        .padding(.leading, 4)
                        .padding(.trailing, 10)
                        .frame(height: 30)
                        .background(Theme.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.line))
                        .opacity(isOn ? 1 : 0.4)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("\(member.name), \(isOn ? "shown" : "hidden")")
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Data

    /// Week: the whole week in expanded width, 3 days from the anchor in medium. Day: one column.
    private var days: [Date] {
        switch mode {
        case .day:
            return [anchor]
        case .week where layout == .expanded:
            let start = calendar.dateInterval(of: .weekOfYear, for: anchor)?.start ?? anchor
            return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        default:
            return (0..<3).compactMap { calendar.date(byAdding: .day, value: $0, to: anchor) }
        }
    }

    private func tasks(on day: Date) -> [FamilyTask] {
        store.tasks(on: day).filter { task in task.assigneeIDs.contains { !hidden.contains($0) } }
    }

    /// 7 AM – 9 PM, stretched to fit anything earlier or later.
    private var hourRange: ClosedRange<Int> {
        let hours = days.flatMap { tasks(on: $0) }
            .filter { !$0.isAllDay }
            .compactMap { $0.dueDate.map { calendar.component(.hour, from: $0) } }
        return min(7, hours.min() ?? 7)...max(21, (hours.max() ?? 20) + 1)
    }

    // MARK: - Time grid

    private var timeGrid: some View {
        let range = hourRange
        let height = CGFloat(range.count) * hourHeight
        return VStack(spacing: 0) {
            dayHeaders.fixedSize(horizontal: false, vertical: true)
            allDayRow
            ScrollViewReader { reader in
                ScrollView {
                    GeometryReader { geo in
                        let column = (geo.size.width - gutter) / CGFloat(days.count)
                        ZStack(alignment: .topLeading) {
                            hourLines(range, width: geo.size.width)
                            ForEach(Array(days.enumerated()), id: \.element) { index, day in
                                dayColumn(day, range: range, width: column, height: height)
                                    .offset(x: gutter + CGFloat(index) * column)
                            }
                        }
                    }
                    .frame(height: height)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                    .id("grid")
                    .overlay(alignment: .topLeading) {
                        // Invisible anchors so the grid opens near the current hour.
                        ForEach(Array(range), id: \.self) { hour in
                            Color.clear.frame(height: 1)
                                .offset(y: CGFloat(hour - range.lowerBound) * hourHeight)
                                .id(hour)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    let hour = max(range.lowerBound, calendar.component(.hour, from: .now) - 2)
                    reader.scrollTo(min(hour, range.upperBound), anchor: .top)
                }
            }
        }
    }

    private var dayHeaders: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: gutter)
            ForEach(days, id: \.self) { day in
                let isToday = calendar.isDateInToday(day)
                Button {
                    withAnimation(Theme.spring) { anchor = day; mode = .day }
                } label: {
                    VStack(spacing: 2) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.ink3)
                        Text(day.formatted(.dateTime.day()))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(isToday ? .white : Theme.ink)
                            .frame(width: 34, height: 34)
                            .background { if isToday { Circle().fill(Theme.ink) } }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
            }
        }
    }

    @ViewBuilder
    private var allDayRow: some View {
        let allDay = days.map { day in tasks(on: day).filter(\.isAllDay) }
        if allDay.contains(where: { !$0.isEmpty }) {
            HStack(alignment: .top, spacing: 0) {
                Text("All day")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.ink3)
                    .frame(width: gutter, alignment: .leading)
                    .padding(.top, 6)
                ForEach(Array(days.enumerated()), id: \.element) { index, _ in
                    VStack(spacing: 3) {
                        ForEach(allDay[index].prefix(2)) { task in
                            EventChip(task: task, compact: true)
                                .onTapGesture { router.push(.taskDetail(task.id)) }
                        }
                        if allDay[index].count > 2 {
                            Text("+\(allDay[index].count - 2) more")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(Theme.ink3)
                        }
                    }
                    .padding(.horizontal, 2)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .padding(.bottom, 6)
            .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }

    private func hourLines(_ range: ClosedRange<Int>, width: CGFloat) -> some View {
        ForEach(Array(range), id: \.self) { hour in
            let y = CGFloat(hour - range.lowerBound) * hourHeight
            HStack(spacing: 0) {
                Text(hourLabel(hour))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.ink3)
                    .frame(width: gutter - 6, alignment: .leading)
                    .offset(y: -7)
                Rectangle().fill(Theme.line).frame(height: 1)
            }
            .frame(width: width)
            .offset(y: y)
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(.dateTime.hour())
    }

    private func dayColumn(_ day: Date, range: ClosedRange<Int>, width: CGFloat, height: CGFloat) -> some View {
        let isToday = calendar.isDateInToday(day)
        let placed = layoutEvents(tasks(on: day).filter { !$0.isAllDay }, range: range)
        let lanes = (placed.map(\.lane).max() ?? 0) + 1
        let laneWidth = (width - 6) / CGFloat(lanes)

        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(isToday ? Theme.surface2.opacity(0.7) : .clear)
                .overlay(alignment: .leading) { Rectangle().fill(Theme.line).frame(width: 1) }
            ForEach(placed, id: \.task.id) { item in
                EventChip(task: item.task, compact: false)
                    .frame(width: laneWidth - 2, height: 46, alignment: .top)
                    .offset(x: 3 + CGFloat(item.lane) * laneWidth, y: item.y)
                    .onTapGesture { router.push(.taskDetail(item.task.id)) }
                    .accessibilityAddTraits(.isButton)
            }
            if isToday {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let y = offset(for: context.date, range: range)
                    if y >= 0 && y <= height {
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Theme.urgent).frame(height: 1.5)
                            Circle().fill(Theme.urgent).frame(width: 8, height: 8).offset(x: -4)
                        }
                        .offset(y: y - 0.75)
                        .accessibilityHidden(true)
                    }
                }
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    private func offset(for date: Date, range: ClosedRange<Int>) -> CGFloat {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hours = Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60 - Double(range.lowerBound)
        return CGFloat(hours) * hourHeight
    }

    /// Side-by-side lanes for tasks that would cover each other.
    private func layoutEvents(_ list: [FamilyTask], range: ClosedRange<Int>) -> [(task: FamilyTask, y: CGFloat, lane: Int)] {
        var laneEnds: [CGFloat] = []
        return list.compactMap { task in
            guard let due = task.dueDate else { return nil }
            let y = offset(for: due, range: range)
            let lane = laneEnds.firstIndex { $0 <= y } ?? laneEnds.count
            if lane == laneEnds.count { laneEnds.append(0) }
            laneEnds[lane] = y + 48
            return (task, y, lane)
        }
    }

    // MARK: - Month

    private var monthGrid: some View {
        let start = calendar.dateInterval(of: .month, for: anchor)?.start ?? anchor
        let gridStart = calendar.dateInterval(of: .weekOfYear, for: start)?.start ?? start
        let cells = (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

        return ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(cells.prefix(7), id: \.self) { day in
                    Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                }
                ForEach(cells, id: \.self) { day in
                    monthCell(day, inMonth: calendar.isDate(day, equalTo: anchor, toGranularity: .month))
                }
            }
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
    }

    private func monthCell(_ day: Date, inMonth: Bool) -> some View {
        let list = tasks(on: day)
        let isToday = calendar.isDateInToday(day)
        return Button {
            withAnimation(Theme.spring) { anchor = day; mode = .day }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(day.formatted(.dateTime.day()))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isToday ? .white : (inMonth ? Theme.ink : Theme.ink3))
                    .frame(width: 24, height: 24)
                    .background { if isToday { Circle().fill(Theme.ink) } }
                ForEach(list.prefix(3)) { task in
                    HStack(spacing: 4) {
                        Capsule().fill(task.priority.color).frame(width: 3, height: 11)
                        Text(task.title).font(.system(size: 10.5, weight: .medium)).lineLimit(1)
                    }
                    .foregroundStyle(task.isDone ? Theme.ink3 : Theme.ink)
                }
                if list.count > 3 {
                    Text("+\(list.count - 3)").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.ink3)
                }
                Spacer(minLength: 0)
            }
            .padding(6)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .background(inMonth ? Theme.surface : Theme.surface.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted)), \(list.count) tasks")
    }
}

/// A task in the grid: soft priority colour, coloured edge, title, time and the assignee's face.
private struct EventChip: View {
    @EnvironmentObject private var store: FamilyStore
    let task: FamilyTask
    let compact: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle().fill(task.priority.color).frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(task.isDone ? Theme.ink3 : task.priority.textColor)
                    .strikethrough(task.isDone, color: Theme.ink3)
                    .lineLimit(1)
                if !compact {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.ink2)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, compact ? 4 : 5)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: compact ? nil : .infinity, alignment: .topLeading)
        .background(task.priority.softColor.opacity(task.isDone ? 0.5 : 1))
        .overlay(alignment: compact ? .trailing : .bottomTrailing) {
            if let first = store.members(task.assigneeIDs).first {
                AvatarView(member: first, size: 15).padding(4)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(task.title), \(subtitle)")
    }

    private var subtitle: String {
        guard let due = task.dueDate else { return "" }
        var parts = [task.isAllDay ? "Any time" : due.formatted(date: .omitted, time: .shortened)]
        if let location = task.location, let place = store.place(for: location) { parts.append(place.name) }
        if !task.checklist.isEmpty {
            parts.append("\(task.checklist.filter(\.isDone).count)/\(task.checklist.count)")
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    NavigationStack { CalendarWeekView() }
        .environment(\.layoutClass, .expanded)
        .previewEnvironment()
}
