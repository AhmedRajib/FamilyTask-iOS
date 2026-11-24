import SwiftUI
import MapKit

struct TaskDetailView: View {
    @EnvironmentObject private var store: FamilyStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutClass) private var layout
    @EnvironmentObject private var router: Router
    let taskID: UUID
    /// Tablet (expanded): shown beside the list instead of pushed, so it draws its own top buttons.
    var isPane = false

    @State private var confirmDelete = false
    @State private var showDecline = false
    @State private var declineReason = ""

    var body: some View {
        if let task = store.task(taskID) {
            content(task)
        } else {
            UnavailableView(title: "Task removed", systemImage: "trash")
        }
    }

    private var perms: Permissions { store.permissions }
    private var me: Member { store.me }

    private func content(_ task: FamilyTask) -> some View {
        let creator = store.member(task.creatorID)
        return ScrollView {
            if layout.isTablet {
                wideContent(task, creator: creator)
            } else {
                phoneContent(task, creator: creator)
            }
        }
        .background(Theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            if !isPane {
                if perms.canEdit(task) {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") { router.push(.editTask(task.id)) }
                            .fontWeight(.semibold)
                    }
                }
                if perms.canDelete(task) {
                    ToolbarItem(placement: .primaryAction) { moreMenu(task) }
                }
            }
        }
        .confirmationDialog("Delete this task?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if isPane { router.clearSelection() } else { dismiss() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { store.delete(task.id) }
            }
        } message: {
            Text("It will be removed for everyone in the family.")
        }
        .alert("Can't do it?", isPresented: $showDecline) {
            TextField("Reason (optional)", text: $declineReason)
            Button("Send", role: .destructive) {
                withAnimation(Theme.spring) { store.decline(task.id, reason: declineReason) }
                declineReason = ""
            }
            Button("Cancel", role: .cancel) { declineReason = "" }
        } message: {
            Text("\(creator?.name ?? "They") will see your reason.")
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { actionBar(task) }
    }

    private func moreMenu(_ task: FamilyTask) -> some View {
        Menu {
            Button(role: .destructive) { confirmDelete = true } label: {
                Label("Delete task", systemImage: "trash")
            }
        } label: {
            Image(systemName: isPane ? "ellipsis" : "ellipsis.circle").foregroundStyle(Theme.ink)
        }
        .accessibilityLabel("More")
    }

    @ViewBuilder
    private func editedLine(_ task: FamilyTask) -> some View {
        if let editorID = task.editedByID, let editedAt = task.editedAt {
            let editor = store.member(editorID)
            Label("Edited by \(editor?.id == me.id ? "you" : editor?.name ?? "someone") · \(editedAt.formatted(.relative(presentation: .named)))",
                  systemImage: "pencil")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.ink3)
        }
    }

    // MARK: - Tablet layout (T1 detail)

    /// Header, then two columns: facts and checklist on the left, notes on the right.
    private func wideContent(_ task: FamilyTask, creator: Member?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if isPane && (perms.canEdit(task) || perms.canDelete(task)) {
                HStack(spacing: 8) {
                    Spacer()
                    if perms.canEdit(task) {
                        Button { router.push(.editTask(task.id)) } label: {
                            Image(systemName: "pencil").paneButton()
                        }
                        .accessibilityLabel("Edit task")
                    }
                    if perms.canDelete(task) {
                        moreMenu(task).paneButton()
                    }
                }
                .padding(.bottom, 4)
            }
            Text("From \(creator?.id == me.id ? "you" : creator?.name ?? "someone") · \(task.createdAt.formatted(.relative(presentation: .named)))")
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink2)
            Text(task.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(task.isDone ? Theme.ink3 : Theme.ink)
                .strikethrough(task.isDone, color: Theme.ink3)
                .padding(.top, 2)
                .padding(.bottom, task.editedByID == nil ? 14 : 4)
            editedLine(task).padding(.bottom, 14)

            statusBanner(task, creator: creator)

            HStack(alignment: .top, spacing: 22) {
                VStack(alignment: .leading, spacing: 0) {
                    infoGrid(task, creator: creator)
                    if let location = task.location, let place = store.place(for: location) {
                        locationCard(place, trigger: location.trigger)
                    }
                    if !task.checklist.isEmpty {
                        checklist(task).padding(.top, 20)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Notes")
                    Text(task.notes.isEmpty ? "No notes" : task.notes)
                        .font(.system(size: 15))
                        .foregroundStyle(task.notes.isEmpty ? Theme.ink3 : Theme.ink2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                }
                // Facts get the room; notes keep a readable column.
                .frame(minWidth: 190, idealWidth: 250, maxWidth: 300)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .frame(maxWidth: TabletMetrics.detailMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(Theme.spring, value: task.status)
    }

    // MARK: - Phone layout

    private func phoneContent(_ task: FamilyTask, creator: Member?) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                statusBanner(task, creator: creator)

                Text(task.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(task.isDone ? Theme.ink3 : Theme.ink)
                    .strikethrough(task.isDone, color: Theme.ink3)
                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.ink2)
                        .padding(.top, 6)
                }
                editedLine(task).padding(.top, 8)

                infoGrid(task, creator: creator)
                    .padding(.top, 18)
                if let location = task.location, let place = store.place(for: location) {
                    locationCard(place, trigger: location.trigger)
                }

                if !task.checklist.isEmpty {
                    checklist(task).padding(.top, 20)
                }
            }
            .padding(20)
            .animation(Theme.spring, value: task.status)
    }

    // MARK: - Banner

    @ViewBuilder
    private func statusBanner(_ task: FamilyTask, creator: Member?) -> some View {
        switch task.status {
        case .open where task.priority == .urgent:
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let overdue = task.dueDate.map { $0 < context.date } ?? false
                banner(
                    icon: "exclamationmark.triangle.fill",
                    title: task.dueDate.map { overdue ? "Urgent · overdue" : "Urgent · due \(DueFormat.countdown(to: $0, now: context.date))" } ?? "Urgent",
                    subtitle: "\(creator?.id == me.id ? "You" : creator?.name ?? "Someone") marked this as urgent",
                    color: Theme.urgent
                )
            }
        case .requested:
            banner(icon: "hand.raised.fill", title: "Request from \(creator?.name ?? "someone")",
                   subtitle: "Accept it to add it to your list", color: Theme.brand)
        case .declined:
            banner(icon: "xmark.circle.fill", title: "Declined",
                   subtitle: task.declineReason.map { "“\($0)”" } ?? "No reason given", color: Theme.ink2)
        case .done:
            let doneBy = task.completedByID.flatMap(store.member)
            banner(icon: "checkmark.circle.fill",
                   title: "Done by \(doneBy?.id == me.id ? "you" : doneBy?.name ?? "someone")",
                   subtitle: task.completedAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "",
                   color: Theme.done)
        default:
            EmptyView()
        }
    }

    private func banner(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .pulseEffect(isActive: color == Theme.urgent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .bold))
                Text(subtitle).font(.system(size: 12.5)).opacity(0.9)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.bottom, 18)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Info

    private func infoGrid(_ task: FamilyTask, creator: Member?) -> some View {
        let assignees = store.members(task.assigneeIDs)
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
            InfoTile(label: "Assigned to") {
                HStack(spacing: 6) {
                    AvatarStack(members: assignees, size: 22)
                    Text(assignees.count == 1 ? (assignees[0].id == me.id ? "You" : assignees[0].name) : "\(assignees.count) people")
                }
            }
            InfoTile(label: "From") {
                HStack(spacing: 6) {
                    if let creator { AvatarView(member: creator, size: 22) }
                    Text(creator?.id == me.id ? "You" : creator?.name ?? "—")
                }
            }
            InfoTile(label: "Due") {
                Label(DueFormat.short(task) ?? "No date", systemImage: "clock")
                    .foregroundStyle(DueFormat.isOverdue(task) ? Theme.urgent : Theme.ink)
            }
            if task.repeatRule != .never {
                InfoTile(label: "Repeats") { Label(task.repeatRule.title, systemImage: "repeat") }
            }
            if task.reminder != .none {
                InfoTile(label: "Reminder") { Label(task.reminder.title, systemImage: "bell") }
            }
        }
    }

    // MARK: - Location

    private func locationCard(_ place: Place, trigger: PlaceTrigger) -> some View {
        HStack(spacing: 12) {
            Text(place.emoji)
                .font(.system(size: 17))
                .frame(width: 34, height: 34)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                Text([place.address, trigger == .arriving ? "when arriving" : "when leaving"]
                    .filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.ink3)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button("Directions") { openDirections(to: place) }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.brand)
        }
        .card(padding: 12)
        .padding(.top, 8)
    }

    private func openDirections(to place: Place) {
        let item = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)))
        item.name = place.name
        item.openInMaps()
    }

    // MARK: - Checklist

    private func checklist(_ task: FamilyTask) -> some View {
        let canTick = perms.canComplete(task) && task.status == .open
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Checklist").font(.system(size: 16, weight: .semibold))
                Text("\(task.checklist.filter(\.isDone).count)/\(task.checklist.count)")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink3)
                    .contentTransition(.numericText())
            }
            VStack(spacing: 0) {
                ForEach(Array(task.checklist.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 12) {
                        CheckBox(isOn: item.isDone, size: 20) {
                            withAnimation(Theme.spring) { store.toggleChecklistItem(task: task.id, item: item.id) }
                        }
                        .disabled(!canTick)
                        Text(item.title)
                            .font(.system(size: 15))
                            .foregroundStyle(item.isDone ? Theme.ink3 : Theme.ink)
                            .strikethrough(item.isDone, color: Theme.ink3)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    if index < task.checklist.count - 1 { RowDivider(leading: 46) }
                }
            }
            .card(padding: 0)
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private func actionBar(_ task: FamilyTask) -> some View {
        let isAssignee = task.assigneeIDs.contains(me.id)
        let content: AnyView? = {
            switch task.status {
            case .requested where isAssignee:
                return AnyView(HStack(spacing: 10) {
                    Button("Can't do it") { showDecline = true }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Accept") { withAnimation(Theme.spring) { store.accept(task.id) } }
                        .buttonStyle(PrimaryButtonStyle())
                        .layoutPriority(1)
                })
            case .open where perms.canComplete(task):
                return AnyView(HStack(spacing: 10) {
                    if isAssignee && task.creatorID != me.id {
                        Button("Can't do it") { showDecline = true }
                            .buttonStyle(SecondaryButtonStyle())
                            .frame(maxWidth: 130)
                    }
                    Button {
                        withAnimation(Theme.spring) { store.toggleDone(task.id) }
                    } label: {
                        Label("Mark as done", systemImage: "checkmark")
                    }
                    .buttonStyle(PrimaryButtonStyle(color: Theme.done))
                })
            case .done where perms.canComplete(task):
                return AnyView(
                    Button("Reopen task") { withAnimation(Theme.spring) { store.toggleDone(task.id) } }
                        .buttonStyle(SecondaryButtonStyle())
                )
            default:
                return nil
            }
        }()
        if let content {
            content
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(Theme.background)
                .haptic(.success, trigger: task.status) { _, new in new == .done }
        }
    }
}

private struct InfoTile<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.ink3)
            content
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 12)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let store = FamilyStore.preview()
    return NavigationStack { TaskDetailView(taskID: store.tasks[0].id) }
        .environmentObject(store)
        .environmentObject(Router())
}

private extension View {
    /// Square top-right button in the tablet detail pane.
    func paneButton() -> some View {
        font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(width: 40, height: 40)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line))
    }
}
