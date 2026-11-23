import SwiftUI

/// Add or edit a quick task: what New Task fills in when someone taps it.
struct TemplateEditorView: View {
    let templateID: UUID?
    @EnvironmentObject private var store: FamilyStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var emoji = "⭐"
    @State private var priority: Priority = .normal
    @State private var timeID: UUID?
    @State private var repeatRule: RepeatRule = .never
    @State private var placeID: UUID?
    @State private var checklist: [ChecklistItem] = []
    @State private var newItem = ""
    @State private var didLoad = false
    @State private var confirmDelete = false
    @FocusState private var focus: Field?

    private enum Field: Hashable { case title, checklist }

    private static let suggestions = ["🏫", "🛒", "💊", "⚽", "🧹", "🐶", "🗑️"]

    private var existing: TaskTemplate? { store.template(templateID) }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TextField("Name, like \"Football practice\"", text: $title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .focused($focus, equals: .title)
                    .submitLabel(.done)
                    .card()

                SectionLabel("Emoji").padding(.top, 20).padding(.bottom, 8)
                EmojiPicker(selection: $emoji, suggestions: Self.suggestions)

                SectionLabel("Priority").padding(.top, 20).padding(.bottom, 8)
                prioritySegment

                SectionLabel("Fills in automatically").padding(.top, 20).padding(.bottom, 8)
                detailsCard
                Text("Time and Place use your family's saved times and places.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink3)
                    .padding(.horizontal, 4)
                    .padding(.top, 8)

                SectionLabel("Checklist").padding(.top, 20).padding(.bottom, 8)
                checklistCard

                if existing != nil {
                    EditorDeleteButton(title: "Delete quick task") { confirmDelete = true }
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .navigationTitle(existing == nil ? "New quick task" : "Edit quick task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            EditorSaveBar(title: existing == nil ? "Save quick task" : "Save",
                          enabled: !trimmedTitle.isEmpty, action: save)
        }
        .alert("Delete \"\(existing?.title ?? "")\"?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                guard let templateID else { return }
                store.deleteTemplate(templateID)
                Haptic.success.play()
                dismiss()
            }
        } message: {
            Text("It's removed for the whole family. Tasks already created from it don't change.")
        }
        .onAppear(perform: load)
    }

    // MARK: - Priority

    private var prioritySegment: some View {
        HStack(spacing: 6) {
            ForEach(Priority.allCases) { option in
                let isOn = priority == option
                Button {
                    withAnimation(.quick(0.25)) { priority = option }
                } label: {
                    HStack(spacing: 5) {
                        if option == .urgent {
                            Image(systemName: "bolt.fill").font(.system(size: 10, weight: .bold))
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
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .haptic(.selection, trigger: priority)
    }

    // MARK: - Details

    private var detailsCard: some View {
        VStack(spacing: 0) {
            Menu {
                Picker("Time", selection: $timeID) {
                    Text("No set time").tag(UUID?.none)
                    ForEach(store.family.times) { Text("\($0.emoji) \($0.name) · \($0.timeText)").tag(UUID?.some($0.id)) }
                }
            } label: {
                DetailRow(icon: "clock", tint: Theme.brand, title: "Time",
                          value: store.time(timeID).map { "\($0.emoji) \($0.name)" } ?? "None")
            }

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
                Picker("Place", selection: $placeID) {
                    Text("No place").tag(UUID?.none)
                    ForEach(store.family.places) { Text("\($0.emoji) \($0.name)").tag(UUID?.some($0.id)) }
                }
            } label: {
                DetailRow(icon: "mappin", tint: Theme.done, title: "Place",
                          value: store.place(placeID).map { "\($0.emoji) \($0.name)" } ?? "None")
            }
        }
        .card(padding: 0)
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

    // MARK: - Load & save

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let existing else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { focus = .title }
            return
        }
        title = existing.title
        emoji = existing.emoji
        priority = existing.priority
        timeID = store.time(existing.timeShortcutID)?.id
        repeatRule = existing.repeatRule
        placeID = store.place(existing.placeID)?.id
        checklist = existing.checklist.map { ChecklistItem(title: $0) }
    }

    private func save() {
        // Keep whatever is still being typed in "Add an item".
        addItem()
        var item = existing ?? TaskTemplate(title: "", emoji: "", priority: .normal, repeatRule: .never, checklist: [])
        item.title = trimmedTitle
        item.emoji = emoji
        item.priority = priority
        item.timeShortcutID = timeID
        item.repeatRule = repeatRule
        item.placeID = placeID
        item.checklist = checklist.map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        store.saveTemplate(item)
        Haptic.success.play()
        dismiss()
    }
}

#Preview {
    NavigationStack { TemplateEditorView(templateID: nil) }.previewEnvironment()
}
