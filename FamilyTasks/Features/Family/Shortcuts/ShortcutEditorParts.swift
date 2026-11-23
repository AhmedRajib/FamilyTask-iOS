import SwiftUI

/// A row of suggested emoji; "•••" opens a bigger grid.
struct EmojiPicker: View {
    @Binding var selection: String
    let suggestions: [String]
    @State private var showAll = false

    static let all = [
        "🏠", "🏫", "🛒", "🏥", "👵", "👴", "⚽", "🏀", "🎒", "🍽️", "🌙", "☀️",
        "🛁", "🕌", "⛪", "🏢", "💼", "🚗", "🚌", "🐶", "🐱", "💊", "🧹", "🧺",
        "🗑️", "🌱", "📚", "✏️", "🎹", "🎨", "🏊", "🚲", "🍎", "🥛", "🍞", "🎂",
        "🎁", "💡", "🔧", "📦", "💰", "📞", "🧸", "👶", "🦷", "✂️", "🏖️", "⭐",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(rowEmoji, id: \.self) { cell($0) }
                Button { withAnimation(Theme.spring) { showAll.toggle() } } label: {
                    Image(systemName: showAll ? "chevron.up" : "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.ink2)
                        .frame(width: 38, height: 38)
                        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(showAll ? "Fewer emoji" : "More emoji")
            }
            if showAll {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                    ForEach(Self.all, id: \.self) { cell($0) }
                }
                .card(padding: 8)
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }
        }
        .haptic(.selection, trigger: selection)
    }

    /// Suggestions, with the current choice first if it isn't one of them.
    private var rowEmoji: [String] {
        let base = Array(suggestions.prefix(7))
        return base.contains(selection) ? base : [selection] + base.prefix(6)
    }

    private func cell(_ emoji: String) -> some View {
        let isOn = emoji == selection
        return Button { selection = emoji } label: {
            Text(emoji)
                .font(.system(size: 19))
                .frame(width: 38, height: 38)
                .background(isOn ? Theme.surface : Theme.surface2,
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(isOn ? Theme.ink : .clear, lineWidth: 2))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Large single-line name field in a card.
struct NameField: View {
    let placeholder: String
    @Binding var text: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .focused(focused)
            .submitLabel(.done)
            .card()
    }
}

/// Pinned Save button at the bottom of an editor page.
struct EditorSaveBar: View {
    let title: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!enabled)
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Theme.background)
    }
}

/// Soft red "Delete …" button shown when editing an existing shortcut.
struct EditorDeleteButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.urgent)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Theme.urgentSoft, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .padding(.top, 24)
    }
}

/// "Used by 1 quick task (Nana's medicine)."
func usedByText(_ templates: [TaskTemplate]) -> String? {
    guard !templates.isEmpty else { return nil }
    let count = templates.count == 1 ? "1 quick task" : "\(templates.count) quick tasks"
    return "Used by \(count) (\(templates.map(\.title).formatted(.list(type: .and))))."
}

/// Message for the delete confirmation: what happens to quick tasks that use it.
func deleteMessage(usedBy templates: [TaskTemplate], losing what: String) -> String {
    let base = "It's removed for the whole family. Tasks already created don't change."
    guard !templates.isEmpty else { return base }
    let names = templates.map(\.title).formatted(.list(type: .and))
    return "It's removed for the whole family. \(names) will keep working, just without \(what)."
}
