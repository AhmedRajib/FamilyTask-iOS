import SwiftUI

/// Full-screen "New Task" page, pushed from the ＋ button (or a quick-task shortcut).
struct NewTaskView: View {
    @EnvironmentObject private var store: FamilyStore
    @Environment(\.dismiss) private var dismiss
    let templateID: UUID?

    @State private var title = ""
    @State private var notes = ""
    @State private var assignees: Set<UUID> = []
    @State private var priority: Priority = .normal
    @State private var dueDate: Date?
    @State private var isAllDay = false
    @State private var repeatRule: RepeatRule = .never
    @State private var reminder: ReminderOption = .none
    @State private var location: LocationReminder?
    @State private var checklist: [ChecklistItem] = []
    @State private var newItem = ""
    @State private var isPrivate = false
    @State private var activeTemplate: UUID?
    @State private var showWhen = false
    @State private var didSetUp = false
    @FocusState private var focus: Field?

    private enum Field { case title, notes, checklist }

    private var perms: Permissions { store.permissions }
    private var me: Member { store.me }
    private var isJustMe: Bool { assignees == [me.id] }
    private var urgentAllowed: Bool { perms.canUseUrgent(assignees: assignees) }

    /// True when a child picks an adult: the task goes as a request.
    private var isRequest: Bool {
        store.members(Array(assignees)).contains { perms.assignAbility(to: $0) == .request }
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedTitle.isEmpty && !assignees.isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                quickStart
                titleCard

                SectionLabel("Assign to").padding(.top, 20).padding(.bottom, 8)
                assignCard

                SectionLabel("Priority").padding(.top, 20).padding(.bottom, 8)
                prioritySegment

                SectionLabel("Details").padding(.top, 20).padding(.bottom, 8)
                detailsCard

                SectionLabel("Checklist").padding(.top, 20).padding(.bottom, 8)
                checklistCard

                if isJustMe {
                    privateToggle
                        .padding(.top, 20)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .animation(Theme.spring, value: isJustMe)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .navigationTitle("New Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) { saveBar }
        .sheet(isPresented: $showWhen) {
            WhenPickerSheet(dueDate: $dueDate, isAllDay: $isAllDay, times: store.family.times)
        }
        .onAppear(perform: setUp)
        .onChange(of: assignees) { _ in
            if !urgentAllowed && priority == .urgent { priority = .high }
            if !isJustMe { isPrivate = false }
        }
        .onChange(of: dueDate) { _ in
            if dueDate == nil { reminder = .none }
        }
    }

    // MARK: - Set-up

    private func setUp() {
        guard !didSetUp else { return }
        didSetUp = true
        assignees = [me.id]
        if let template = store.template(templateID) {
            apply(template)
        } else {
            // Wait for the push animation before raising the keyboard.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { focus = .title }
        }
    }

    private func apply(_ template: TaskTemplate) {
        title = template.title
        priority = (template.priority == .urgent && !urgentAllowed) ? .high : template.priority
        repeatRule = template.repeatRule
        location = template.placeID.map { LocationReminder(placeID: $0, trigger: .arriving) }
        checklist = template.checklist.map { ChecklistItem(title: $0) }
        if let time = store.time(template.timeShortcutID) {
            dueDate = time.nextOccurrence()
            isAllDay = false
        }
        activeTemplate = template.id
    }

    // MARK: - Quick start

    @ViewBuilder
    private var quickStart: some View {
        if !store.family.templates.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(store.family.templates) { template in
                        let isOn = activeTemplate == template.id
                        Button {
                            withAnimation(Theme.spring) { apply(template) }
                        } label: {
                            Text("\(template.emoji) \(template.title)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isOn ? .white : Theme.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isOn ? Theme.ink : Theme.surface, in: Capsule())
                                .overlay(Capsule().strokeBorder(isOn ? Theme.ink : Theme.line))
                        }
                        .buttonStyle(PressableStyle())
                        .haptic(.selection, trigger: isOn)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Title

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("What needs doing?", text: $title, axis: .vertical)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .focused($focus, equals: .title)
                .submitLabel(.next)
                .onSubmit { focus = .notes }
            TextField("Add a note", text: $notes, axis: .vertical)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink2)
                .focused($focus, equals: .notes)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: - Assign

    private var assignCard: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(store.family.members) { assignButton($0) }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 14)
        }
        .scrollIndicators(.hidden)
        .card(padding: 6)
    }

    private func assignButton(_ member: Member) -> some View {
        let ability = perms.assignAbility(to: member)
        let isOn = assignees.contains(member.id)
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isOn { assignees.remove(member.id) } else { assignees.insert(member.id) }
            }
        } label: {
            VStack(spacing: 5) {
                AvatarView(member: member, size: 44)
                    .opacity(isOn ? 1 : 0.45)
                    .overlay(Circle().strokeBorder(isOn ? Theme.ink : .clear, lineWidth: 2).padding(-4))
                    .overlay(alignment: .topTrailing) {
                        if isOn {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(width: 17, height: 17)
                                .background(Theme.ink, in: Circle())
                                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                                .offset(x: 5, y: -5)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .scaleEffect(isOn ? 1 : 0.94)
                Text(member.id == me.id ? "Me" : member.name)
                    .font(.system(size: 11.5, weight: isOn ? .semibold : .regular))
                    .foregroundStyle(isOn ? Theme.ink : Theme.ink2)
                Text(ability == .request ? "Ask" : " ")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Theme.brand)
            }
            .padding(.top, 4)
        }
        .buttonStyle(PressableStyle())
        .disabled(ability == .notAllowed)
        .opacity(ability == .notAllowed ? 0.3 : 1)
        .haptic(.selection, trigger: isOn)
        .accessibilityLabel(member.id == me.id ? "Me" : member.name)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - Priority

    private var prioritySegment: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(Priority.allCases) { option in
                    let isOn = priority == option
                    let allowed = option != .urgent || urgentAllowed
                    Button {
                        withAnimation(.quick(0.25)) { priority = option }
                    } label: {
                        HStack(spacing: 5) {
                            if option == .urgent {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .bounceEffect(value: isOn)
                            } else {
                                Circle().fill(option.color).frame(width: 7, height: 7)
                            }
                            Text(option.title)
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isOn ? option.textColor : Theme.ink2)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(isOn ? option.softColor : Theme.surface,
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(isOn ? option.color : Theme.line, lineWidth: 1.5))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(!allowed)
                    .opacity(allowed ? 1 : 0.35)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .haptic(.selection, trigger: priority)

            if !urgentAllowed {
                Text("Urgent is only for tasks you do yourself.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink3)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Details

    private var whenText: String {
        dueDate.map { DueFormat.describe($0, allDay: isAllDay) } ?? "Add date"
    }

    private var locationText: String {
        guard let location, let place = store.place(location.placeID) else { return "None" }
        return "\(place.name) · \(location.trigger.title.lowercased())"
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            Button { showWhen = true } label: {
                DetailRow(icon: "calendar", tint: Theme.brand, title: "When", value: whenText,
                          valueColor: dueDate == nil ? Theme.ink3 : Theme.ink)
            }
            .buttonStyle(.plain)

            RowDivider()
            Menu {
                Picker("Repeat", selection: $repeatRule) {
                    ForEach(RepeatRule.allCases) { Text($0.title).tag($0) }
                }
            } label: {
                DetailRow(icon: "repeat", tint: Theme.purple, title: "Repeat", value: repeatRule.title)
            }

            RowDivider()
            Menu {
                Picker("Reminder", selection: $reminder) {
                    ForEach(ReminderOption.allCases) { Text($0.title).tag($0) }
                }
            } label: {
                DetailRow(icon: "bell.fill", tint: Theme.high, title: "Reminder",
                          value: dueDate == nil ? "Set a date first" : reminder.title)
            }
            .disabled(dueDate == nil)

            RowDivider()
            Menu {
                Button("None") { location = nil }
                ForEach(store.family.places) { place in
                    Button("\(place.emoji) \(place.name)") {
                        location = LocationReminder(placeID: place.id, trigger: location?.trigger ?? .arriving)
                    }
                }
                if location != nil {
                    Picker("Remind when", selection: triggerBinding) {
                        ForEach(PlaceTrigger.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                }
            } label: {
                DetailRow(icon: "mappin", tint: Theme.done, title: "Location", value: locationText)
            }
        }
        .card(padding: 0)
    }

    private var triggerBinding: Binding<PlaceTrigger> {
        Binding(
            get: { location?.trigger ?? .arriving },
            set: { location?.trigger = $0 }
        )
    }

    // MARK: - Checklist

    private var checklistCard: some View {
        VStack(spacing: 0) {
            ForEach($checklist) { $item in
                HStack(spacing: 10) {
                    Image(systemName: "circle").font(.system(size: 16)).foregroundStyle(Theme.ink3)
                    TextField("Item", text: $item.title).font(.system(size: 15))
                    Button {
                        withAnimation(Theme.spring) { checklist.removeAll { $0.id == item.id } }
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.ink3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(item.title)")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .transition(.opacity.combined(with: .move(edge: .top)))
                RowDivider(leading: 40)
            }
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill").font(.system(size: 16)).foregroundStyle(Theme.brand)
                TextField("Add an item", text: $newItem)
                    .font(.system(size: 15))
                    .focused($focus, equals: .checklist)
                    .submitLabel(.done)
                    .onSubmit(addItem)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .card(padding: 0)
    }

    private func addItem() {
        let text = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        withAnimation(Theme.spring) { checklist.append(ChecklistItem(title: text)) }
        newItem = ""
        focus = .checklist
    }

    // MARK: - Private

    private var privateToggle: some View {
        Toggle(isOn: $isPrivate.animation(Theme.spring)) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Theme.ink2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Private").font(.system(size: 15, weight: .medium))
                    Text("Only you can see this task").font(.system(size: 12)).foregroundStyle(Theme.ink3)
                }
            }
        }
        .tint(Theme.done)
        .card(padding: 12)
    }

    // MARK: - Save

    private var ctaTitle: String {
        let names = store.family.members
            .filter { assignees.contains($0.id) && $0.id != me.id }
            .map(\.name)
        let who = names.count <= 2 ? names.joined(separator: " & ") : "\(names.count) people"
        if assignees.isEmpty { return "Choose who it's for" }
        if names.isEmpty { return "Save task" }
        if isRequest { return "Ask \(who)" }
        if priority == .urgent { return "Send urgent task to \(who)" }
        return "Send to \(who)"
    }

    private var saveBar: some View {
        Button(action: save) {
            Text(ctaTitle).contentTransition(.opacity)
        }
        .buttonStyle(PrimaryButtonStyle(color: priority == .urgent && !isJustMe ? Theme.urgent : Theme.ink))
        .disabled(!canSave)
        .animation(.quick, value: ctaTitle)
        .animation(.quick, value: priority)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Theme.background)
    }

    private func save() {
        let task = FamilyTask(
            title: trimmedTitle,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            creatorID: me.id,
            assigneeIDs: store.family.members.map(\.id).filter(assignees.contains),
            priority: priority,
            dueDate: dueDate,
            isAllDay: isAllDay,
            repeatRule: repeatRule,
            reminder: dueDate == nil ? .none : reminder,
            location: location,
            checklist: checklist.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty },
            isPrivate: isJustMe && isPrivate,
            status: isRequest ? .requested : .open
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(Theme.spring) { store.add(task) }
        dismiss()
    }
}

#Preview {
    NavigationStack { NewTaskView(templateID: nil) }.previewEnvironment()
}
