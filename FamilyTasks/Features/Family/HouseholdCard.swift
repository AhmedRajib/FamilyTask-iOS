import SwiftUI

/// Design 5·B1 (day / evening / night): a little street that follows the clock, the family's
/// name, everyone's share of this week's done tasks, and Add member.
struct HouseholdCard: View {
    /// The Family tab's entrance has started.
    let isShown: Bool
    @EnvironmentObject private var store: FamilyStore
    @EnvironmentObject private var router: Router

    var body: some View {
        // Re-checks the clock every minute, so the scene changes by itself (e.g. at 17:00).
        TimelineView(.everyMinute) { context in
            let time = TimeOfDay(date: context.date)
            card(time: time, date: context.date)
                .animation(.easeInOut(duration: 1), value: time)
        }
    }

    private var joined: [Member] { store.family.members.filter { !$0.isInvited } }

    private func card(time: TimeOfDay, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                StreetScene(time: time, isShown: isShown)
                    .id(time)
                    .transition(.opacity)
            }
            .aspectRatio(308.0 / 92.0, contentMode: .fit)
            .clipped()
            .accessibilityHidden(true)

            HStack(alignment: .top, spacing: 12) {
                Text("🏡")
                    .font(.system(size: 26))
                    .frame(width: 54, height: 54)
                    .background(.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).strokeBorder(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
                    .popIn(isShown, order: 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.family.name)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("\(time.greeting(at: date)) · \(store.family.members.count) \(store.family.members.count == 1 ? "member" : "members")")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.ink2)
                        .contentTransition(.opacity)
                }
                .padding(.top, 30)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, -26)

            WeekShareBar(isShown: isShown)
                .padding(12)
                .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 12)

            HStack {
                HStack(spacing: -8) {
                    ForEach(Array(joined.prefix(4).enumerated()), id: \.element.id) { index, member in
                        AvatarView(member: member, size: 30, ring: .white)
                            .popIn(isShown, order: 3 + index)
                    }
                    if joined.count > 4 {
                        Text("+\(joined.count - 4)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.ink2)
                            .frame(width: 30, height: 30)
                            .background(.white, in: Circle())
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(joined.map(\.name).formatted(.list(type: .and)))
                Spacer()
                if store.permissions.canManageMembers {
                    Button { router.push(.addMember) } label: {
                        Label("Add member", systemImage: "plus")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Theme.ink, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .background(LinearGradient(colors: time.cardColors, startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.black.opacity(0.06)))
    }
}

// MARK: - Week share bar (5·B1)

/// One thick bar split into everyone's colour, sized by how many tasks they finished this week.
private struct WeekShareBar: View {
    let isShown: Bool
    @EnvironmentObject private var store: FamilyStore

    private struct Share: Identifiable {
        let member: Member
        let done: Int
        var id: UUID { member.id }
    }

    var body: some View {
        let members = store.family.members.filter { !$0.isInvited }
        let progress = members.map { ($0, store.weekProgress(for: $0.id)) }
        let done = progress.reduce(0) { $0 + $1.1.done }
        let total = progress.reduce(0) { $0 + $1.1.total }
        let shares = progress.map { Share(member: $0.0, done: $0.1.done) }

        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Family this week").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
                Spacer()
                Text(total == 0 ? "No tasks yet" : "\(done) of \(total) done")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.ink2)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                let gaps = CGFloat(max(shares.filter { $0.done > 0 }.count - 1, 0)) * 2
                let usable = max(geo.size.width - gaps, 0)
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.ink.opacity(0.07))
                    HStack(spacing: 2) {
                        ForEach(Array(shares.filter { $0.done > 0 }.enumerated()), id: \.element.id) { index, share in
                            Rectangle()
                                .fill(share.member.color.gradient)
                                .overlay(alignment: .top) {
                                    LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0)],
                                                   startPoint: .top, endPoint: .center)
                                }
                                .frame(width: isShown && total > 0 ? usable * CGFloat(share.done) / CGFloat(total) : 0)
                                .animation(.spring(response: 0.7, dampingFraction: 0.85)
                                    .delay(0.35 + Double(index) * 0.12), value: isShown)
                        }
                    }
                    .clipShape(Capsule())
                }
            }
            .frame(height: 14)
            .animation(Theme.spring, value: done)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(shares) { share in
                        HStack(spacing: 5) {
                            Circle().fill(share.member.color).frame(width: 8, height: 8)
                            Text(share.member.id == store.me.id ? "Me" : share.member.name)
                                .foregroundStyle(Theme.ink2)
                            Text("\(share.done)").fontWeight(.bold).foregroundStyle(Theme.ink)
                        }
                        .font(.system(size: 12))
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Family this week: \(done) of \(total) tasks done. "
            + shares.map { "\($0.member.name) \($0.done)" }.joined(separator: ", "))
    }
}

// MARK: - Time of day

enum TimeOfDay: Equatable {
    case day, evening, night

    /// Day 06:00–17:00 · Evening 17:00–20:00 · Night 20:00–06:00, on the phone's own clock.
    init(date: Date, calendar: Calendar = .current) {
        switch calendar.component(.hour, from: date) {
        case 6..<17: self = .day
        case 17..<20: self = .evening
        default: self = .night
        }
    }

    func greeting(at date: Date, calendar: Calendar = .current) -> String {
        switch self {
        case .day: calendar.component(.hour, from: date) < 12 ? "Good morning ☀️" : "Good afternoon ☀️"
        case .evening: "Good evening 🌇"
        case .night: "Good night 🌙"
        }
    }

    var cardColors: [Color] {
        switch self {
        case .day: [Color(hex: 0xF1F8FF), Color(hex: 0xEAF4FF)]
        case .evening: [Color(hex: 0xFFF1E2), Color(hex: 0xFFE6D6)]
        case .night: [Color(hex: 0xF3ECF7), Color(hex: 0xEADFF0)]
        }
    }

    fileprivate var palette: ScenePalette {
        switch self {
        case .day:
            ScenePalette(sky: [0x9FD3FF, 0xD9F0FF], hill: 0xB9DFA0, house1: 0xF2A07E, roof1: 0xD46A4C,
                         house2: 0xE58C6A, roof2: 0xC0563B, window: 0xBFE3FF, door: 0x8A4A33,
                         tree: 0x79B862, trunk: 0x8A5A3B)
        case .evening:
            ScenePalette(sky: [0xFFC98F, 0xFFB38A], hill: 0xF29E78, house1: 0xE07F5E, roof1: 0xB9583D,
                         house2: 0xC96A4E, roof2: 0xA44C33, window: 0xFFE08A, door: 0x7E3F2B,
                         tree: 0xC9885B, trunk: 0x8A5A3B)
        case .night:
            ScenePalette(sky: [0x2E2346, 0x5B3F62], hill: 0x2A1D33, house1: 0x3A2A45, roof1: 0x2A1D33,
                         house2: 0x33243F, roof2: 0x22172B, window: 0xFFC966, door: 0xFFB347,
                         tree: 0x2A1D33, trunk: 0x22172B)
        }
    }
}

private struct ScenePalette {
    let sky: [UInt32]
    let hill, house1, roof1, house2, roof2, window, door, tree, trunk: UInt32
}

// MARK: - Street scene

/// The same street in three lights. Drawn on a 308×92 canvas and scaled to fit the card.
private struct StreetScene: View {
    let time: TimeOfDay
    let isShown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var p: ScenePalette { time.palette }

    /// (x, y, w, h) of every window, left to right — they light up in this order at night.
    private static let windows: [CGRect] = [
        CGRect(x: 104, y: 72, width: 8, height: 8), CGRect(x: 117, y: 72, width: 8, height: 8),
        CGRect(x: 149, y: 68, width: 10, height: 10), CGRect(x: 173, y: 68, width: 10, height: 10),
        CGRect(x: 212, y: 75, width: 9, height: 8), CGRect(x: 259, y: 78, width: 8, height: 7),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: p.sky.map { Color(hex: $0) }, startPoint: .top, endPoint: .bottom)
                skyDetails
                hills
                if time == .night { windowGlow }
                houses
                windowsLayer
                tree(x: 60, y: 64, radius: 10, trunk: 18)
                tree(x: 290, y: 70, radius: 8, trunk: 14)
            }
            .frame(width: 308, height: 92, alignment: .topLeading)
            .scaleEffect(geo.size.width / 308, anchor: .topLeading)
        }
    }

    // MARK: Sky

    @ViewBuilder
    private var skyDetails: some View {
        switch time {
        case .day:
            ForEach(Array([(60.0, 22.0, 36.0, 12.0), (73, 18, 22, 14), (190, 16, 26, 10)].enumerated()), id: \.offset) { _, c in
                Ellipse().fill(.white.opacity(0.95))
                    .frame(width: c.2, height: c.3)
                    .position(x: c.0, y: c.1)
                    .offset(x: isShown && !reduceMotion ? 6 : 0)
                    .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: isShown)
            }
            Circle().fill(Color(hex: 0xFFE27A).opacity(0.25)).frame(width: 44, height: 44).position(x: 252, y: 26)
            Circle().fill(Color(hex: 0xFFE27A)).frame(width: 28, height: 28).position(x: 252, y: 26)
        case .evening:
            stars([(40, 18, 1.4), (70, 34, 1)], opacity: 0.8)
            // The low sun sinks a little as the card appears.
            Circle().fill(Color(hex: 0xFFE7B5).opacity(0.85))
                .frame(width: 60, height: 60)
                .position(x: 232, y: 58)
                .offset(y: isShown && !reduceMotion ? 0 : -8)
                .animation(.easeOut(duration: 2.2).delay(0.3), value: isShown)
        case .night:
            stars([(24, 14, 1.2), (110, 12, 1.4), (150, 28, 1), (210, 14, 1.2), (286, 22, 1.1), (96, 46, 0.9)], opacity: 1)
            ZStack {
                Circle().fill(Color(hex: 0xFFE7A8)).frame(width: 24, height: 24)
                Circle().fill(Color(hex: 0x33274A)).frame(width: 22, height: 22).offset(x: 5, y: -4)
            }
            .position(x: 62, y: 34)
        }
    }

    private func stars(_ list: [(CGFloat, CGFloat, CGFloat)], opacity: Double) -> some View {
        ForEach(Array(list.enumerated()), id: \.offset) { _, s in
            Circle().fill(.white.opacity(opacity)).frame(width: s.2 * 2, height: s.2 * 2).position(x: s.0, y: s.1)
        }
    }

    // MARK: Ground & houses

    private var hills: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 92))
            path.addLine(to: CGPoint(x: 0, y: 70))
            path.addCurve(to: CGPoint(x: 140, y: 64), control1: CGPoint(x: 50, y: 60), control2: CGPoint(x: 90, y: 72))
            path.addCurve(to: CGPoint(x: 308, y: 66), control1: CGPoint(x: 190, y: 56), control2: CGPoint(x: 250, y: 56))
            path.addLine(to: CGPoint(x: 308, y: 92))
            path.closeSubpath()
        }
        .fill(Color(hex: p.hill).opacity(0.75))
    }

    private var houses: some View {
        ZStack(alignment: .topLeading) {
            house(left: 96, eaves: 66, width: 36, peak: 15, bottom: 92, fill: p.house1, roof: p.roof1, roofWidth: 3.5)
            house(left: 140, eaves: 60, width: 52, peak: 22, bottom: 92, fill: p.house2, roof: p.roof2, roofWidth: 4)
            Rectangle().fill(Color(hex: p.roof2)).frame(width: 7, height: 12).position(x: 181.5, y: 43)
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: p.door)).frame(width: 10, height: 14).position(x: 166, y: 85)
            house(left: 200, eaves: 70, width: 34, peak: 14, bottom: 92, fill: p.house1, roof: p.roof1, roofWidth: 3.5)
            house(left: 250, eaves: 74, width: 28, peak: 11, bottom: 92, fill: p.house2, roof: nil, roofWidth: 0)
        }
    }

    private func house(left: CGFloat, eaves: CGFloat, width: CGFloat, peak: CGFloat, bottom: CGFloat,
                       fill: UInt32, roof: UInt32?, roofWidth: CGFloat) -> some View {
        let mid = left + width / 2
        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: left, y: eaves))
                path.addLine(to: CGPoint(x: mid, y: eaves - peak))
                path.addLine(to: CGPoint(x: left + width, y: eaves))
                path.addLine(to: CGPoint(x: left + width, y: bottom))
                path.addLine(to: CGPoint(x: left, y: bottom))
                path.closeSubpath()
            }
            .fill(Color(hex: fill))
            if let roof {
                Path { path in
                    path.move(to: CGPoint(x: left - 4, y: eaves + 2))
                    path.addLine(to: CGPoint(x: mid, y: eaves - peak - 4))
                    path.addLine(to: CGPoint(x: left + width + 4, y: eaves + 2))
                }
                .stroke(Color(hex: roof), style: StrokeStyle(lineWidth: roofWidth, lineCap: .round, lineJoin: .round))
            }
        }
    }

    // MARK: Windows

    private var windowsLayer: some View {
        ForEach(Array(Self.windows.enumerated()), id: \.offset) { index, rect in
            RoundedRectangle(cornerRadius: 1.8)
                .fill(Color(hex: p.window))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                // At night the lights come on one by one.
                .opacity(time != .night || isShown || reduceMotion ? 1 : 0.15)
                .animation(.easeOut(duration: 0.4).delay(0.4 + Double(index) * 0.18), value: isShown)
        }
    }

    private var windowGlow: some View {
        ForEach(Array([(108.0, 76.0, 9.0), (121, 76, 9), (154, 73, 11), (178, 73, 11), (216, 79, 9)].enumerated()),
                id: \.offset) { index, g in
            Circle()
                .fill(Color(hex: 0xFFC966).opacity(0.2))
                .frame(width: g.2 * 2, height: g.2 * 2)
                .position(x: g.0, y: g.1)
                .opacity(isShown || reduceMotion ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.5 + Double(index) * 0.18), value: isShown)
        }
    }

    private func tree(x: CGFloat, y: CGFloat, radius: CGFloat, trunk: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color(hex: p.trunk)).frame(width: 3, height: trunk).position(x: x, y: y + radius + trunk / 2)
            Circle().fill(Color(hex: p.tree)).frame(width: radius * 2, height: radius * 2).position(x: x, y: y + radius - 2)
        }
    }
}

#Preview {
    ScrollView {
        HouseholdCard(isShown: true).padding(20)
    }
    .background(Theme.background)
    .previewEnvironment()
}
