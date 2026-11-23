import SwiftUI

struct TaskCard: View {
    @EnvironmentObject private var store: FamilyStore
    let task: FamilyTask

    private var canToggle: Bool {
        store.permissions.canComplete(task) && (task.status == .open || task.status == .done)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CheckBox(isOn: task.isDone) {
                withAnimation(Theme.spring) { store.toggleDone(task.id) }
            }
            .disabled(!canToggle)
            .opacity(canToggle ? 1 : 0.4)
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(task.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(task.isDone ? Theme.ink3 : Theme.ink)
                        .strikethrough(task.isDone, color: Theme.ink3)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    TaskBadge(task: task)
                }
                if !task.isDone { footer }
            }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 14))
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .leading) {
            if task.status == .open {
                Capsule()
                    .fill(task.priority.color)
                    .frame(width: 3)
                    .padding(.vertical, 14)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.line))
        .opacity(task.isDone ? 0.8 : 1)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            // The due time matters most: when space runs out, drop the checklist count, then the place.
            ViewThatFits(in: .horizontal) {
                metaRow(showPlace: true, showChecklist: true)
                metaRow(showPlace: true, showChecklist: false)
                metaRow(showPlace: false, showChecklist: false)
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(Theme.ink2)
            .lineLimit(1)

            Spacer(minLength: 4)
            people
        }
    }

    private func metaRow(showPlace: Bool, showChecklist: Bool) -> some View {
        HStack(spacing: 10) {
            if let due = DueFormat.short(task) {
                let late = DueFormat.isOverdue(task)
                let hot = late || (task.priority == .urgent && Calendar.current.isDateInToday(task.dueDate!))
                meta(late ? "\(due) · late" : due, icon: "clock")
                    .foregroundStyle(hot ? Theme.urgent : Theme.ink2)
                    .fontWeight(hot ? .semibold : .medium)
                    .fixedSize()
            }
            if showPlace, let location = task.location, let place = store.place(for: location) {
                meta(place.name, icon: "mappin").fixedSize()
            }
            if showChecklist, !task.checklist.isEmpty {
                meta("\(task.checklist.filter(\.isDone).count)/\(task.checklist.count)", icon: "checklist").fixedSize()
            }
            if task.repeatRule != .never {
                Image(systemName: "repeat").font(.system(size: 10, weight: .semibold))
            }
            if task.isPrivate {
                Image(systemName: "lock.fill").font(.system(size: 10, weight: .semibold))
            }
        }
    }

    @ViewBuilder
    private var people: some View {
        if task.creatorID != store.me.id, let creator = store.member(task.creatorID) {
            HStack(spacing: 5) {
                Text("from").font(.system(size: 11)).foregroundStyle(Theme.ink3)
                AvatarView(member: creator, size: 22)
            }
        } else {
            AvatarStack(members: store.members(task.assigneeIDs))
        }
    }

    private func meta(_ text: String, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 10.5, weight: .semibold))
            Text(text)
        }
    }
}

#Preview {
    let store = FamilyStore.preview()
    return VStack(spacing: 10) {
        ForEach(store.tasks.prefix(4)) { TaskCard(task: $0) }
    }
    .padding()
    .background(Theme.background)
    .environmentObject(store)
}
