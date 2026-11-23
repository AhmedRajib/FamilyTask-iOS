import SwiftUI

/// Add or edit a family time ("Dinner · 7:00 PM").
struct TimeEditorView: View {
    let timeID: UUID?
    @EnvironmentObject private var store: FamilyStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "🕐"
    @State private var time = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: .now) ?? .now
    @State private var didLoad = false
    @State private var confirmDelete = false
    @FocusState private var nameFocused: Bool

    private static let suggestions = ["🎒", "🏫", "🍽️", "🌙", "☀️", "⚽", "🛁"]

    private var existing: TimeShortcut? { store.time(timeID) }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                NameField(placeholder: "Name, like \"After school\"", text: $name, focused: $nameFocused)

                SectionLabel("Emoji").padding(.top, 20).padding(.bottom, 8)
                EmojiPicker(selection: $emoji, suggestions: Self.suggestions)

                SectionLabel("Time").padding(.top, 20).padding(.bottom, 8)
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .card(padding: 0)

                if let timeID, let used = usedByText(store.templates(usingTime: timeID)) {
                    Text("\(used) Changing the time updates it too.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.ink2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.top, 10)
                }

                if existing != nil {
                    EditorDeleteButton(title: "Delete time") { confirmDelete = true }
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .navigationTitle(existing == nil ? "New time" : "Edit time")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            EditorSaveBar(title: existing == nil ? "Save time" : "Save", enabled: !trimmedName.isEmpty, action: save)
        }
        .alert("Delete \"\(existing?.name ?? "")\"?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                guard let timeID else { return }
                store.deleteTime(timeID)
                Haptic.success.play()
                dismiss()
            }
        } message: {
            Text(deleteMessage(usedBy: timeID.map(store.templates(usingTime:)) ?? [], losing: "a set time"))
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let existing else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { nameFocused = true }
            return
        }
        name = existing.name
        emoji = existing.emoji
        time = existing.date(on: .now)
    }

    private func save() {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        var item = existing ?? TimeShortcut(name: "", emoji: "", hour: 0, minute: 0)
        item.name = trimmedName
        item.emoji = emoji
        item.hour = parts.hour ?? 0
        item.minute = parts.minute ?? 0
        store.saveTime(item)
        Haptic.success.play()
        dismiss()
    }
}

#Preview {
    NavigationStack { TimeEditorView(timeID: nil) }.previewEnvironment()
}
