import SwiftUI

// MARK: - Avatars

struct AvatarView: View {
    let member: Member
    var size: CGFloat = 32
    /// Border colour, used to separate overlapping avatars.
    var ring: Color? = nil

    var body: some View {
        Text(member.initial)
            .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(member.color, in: Circle())
            .overlay {
                if let ring {
                    Circle().strokeBorder(ring, lineWidth: max(1.5, size * 0.07))
                }
            }
            .accessibilityLabel(member.name)
    }
}

struct AvatarStack: View {
    let members: [Member]
    var size: CGFloat = 22
    var ring: Color = Theme.surface

    var body: some View {
        HStack(spacing: -size * 0.32) {
            ForEach(members) { AvatarView(member: $0, size: size, ring: ring) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(members.map(\.name).formatted(.list(type: .and)))
    }
}

// MARK: - Pills

struct Pill: View {
    let text: String
    var systemImage: String? = nil
    var dot: Bool = false
    let foreground: Color
    let background: Color

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 9, weight: .bold))
            } else if dot {
                Circle().frame(width: 6, height: 6)
            }
            Text(text)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(foreground)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(background, in: Capsule())
        .fixedSize()
    }
}

struct PriorityPill: View {
    let priority: Priority

    var body: some View {
        Pill(
            text: priority.title,
            systemImage: priority == .urgent ? "bolt.fill" : nil,
            dot: priority != .urgent,
            foreground: priority.textColor,
            background: priority.softColor
        )
    }
}

/// The badge at the top-right of a task card: status if not open, otherwise priority.
struct TaskBadge: View {
    let task: FamilyTask

    var body: some View {
        switch task.status {
        case .done: Pill(text: "Done", foreground: Theme.done, background: Theme.doneSoft)
        case .requested: Pill(text: "Request", systemImage: "hand.raised.fill", foreground: Theme.brand, background: Theme.brandSoft)
        case .declined: Pill(text: "Declined", foreground: Theme.ink2, background: Theme.surface2)
        case .open: PriorityPill(priority: task.priority)
        }
    }
}

// MARK: - Checkbox

struct CheckBox: View {
    let isOn: Bool
    var size: CGFloat = 24
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .fill(isOn ? Theme.done : Color.clear)
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .strokeBorder(isOn ? Theme.done : Theme.line, lineWidth: 2)
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.5, weight: .heavy))
                        .foregroundStyle(.white)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                }
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle().inset(by: -10))
        }
        .buttonStyle(PressableStyle())
        .haptic(.success, trigger: isOn) { _, new in new }
        .accessibilityLabel(isOn ? "Done" : "Not done")
        .accessibilityHint("Double-tap to toggle")
    }
}

// MARK: - Settings-style row

struct DetailRow: View {
    let icon: String
    let tint: Color
    let title: String
    let value: String
    var valueColor: Color = Theme.ink2
    var showsChevron = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .contentTransition(.opacity)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }
}

struct RowDivider: View {
    var leading: CGFloat = 56
    var body: some View {
        Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, leading)
    }
}

// MARK: - Segmented control with a sliding thumb

struct PillSegmented<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isOn = option == selection
                Button {
                    withAnimation(.quick(0.3)) { selection = option }
                } label: {
                    Text(title(option))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isOn ? Theme.ink : Theme.ink2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if isOn {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Theme.surface)
                                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                                    .matchedGeometryEffect(id: "thumb", in: namespace)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .haptic(.selection, trigger: selection)
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let emoji: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Text(emoji).font(.system(size: 44))
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ink)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }
}

// MARK: - Previews

extension View {
    /// Injects an in-memory store and router for SwiftUI previews.
    func previewEnvironment() -> some View {
        environmentObject(FamilyStore.preview())
            .environmentObject(Router())
            .environmentObject(AppSession.preview)
    }
}
