import SwiftUI

/// Task comments (tablet design T1): face + bubble with name and time, then "Write a comment…".
/// Long-press your own comment to delete it (parents can delete any).
struct CommentsSection: View {
    @EnvironmentObject private var store: FamilyStore
    let task: FamilyTask

    @State private var draft = ""
    @FocusState private var isWriting: Bool

    private var trimmed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        let comments = task.allComments
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                SectionLabel("Comments")
                if !comments.isEmpty {
                    Text("\(comments.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                        .contentTransition(.numericText())
                }
            }

            ForEach(comments) { comment in
                row(comment)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .opacity))
            }

            composer
        }
        .animation(Theme.spring, value: comments.map(\.id))
    }

    private func row(_ comment: TaskComment) -> some View {
        let author = store.member(comment.authorID)
        let isMe = comment.authorID == store.me.id
        return HStack(alignment: .top, spacing: 10) {
            if let author {
                AvatarView(member: author, size: 30)
            } else {
                Circle().fill(Theme.surface2).frame(width: 30, height: 30)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(isMe ? "You" : author?.name ?? "Someone") · \(timeText(comment.createdAt))")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                Text(comment.text)
                    .font(.system(size: 14.5))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
            .contextMenu {
                if store.canDeleteComment(comment) {
                    Button(role: .destructive) {
                        withAnimation(Theme.spring) { store.deleteComment(comment.id, from: task.id) }
                    } label: {
                        Label("Delete comment", systemImage: "trash")
                    }
                }
            }
            Spacer(minLength: 24)
        }
        .accessibilityElement(children: .combine)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Write a comment…", text: $draft, axis: .vertical)
                .font(.system(size: 14.5))
                .lineLimit(1...5)
                .focused($isWriting)
                .submitLabel(.send)
                .onSubmit(send)
            if !trimmed.isEmpty {
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Theme.brand)
                }
                .buttonStyle(PressableStyle())
                .keyboardShortcut(.return, modifiers: .command)
                .accessibilityLabel("Send comment")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .frame(minHeight: 44)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(isWriting ? Theme.ink3 : Theme.line))
        .animation(.quick(0.2), value: trimmed.isEmpty)
    }

    private func send() {
        guard !trimmed.isEmpty else { return }
        Haptic.light.play()
        withAnimation(Theme.spring) { store.addComment(to: task.id, text: trimmed) }
        draft = ""
    }

    /// "1:05 PM" today, otherwise "Mon 1:05 PM" / "23 Nov".
    private func timeText(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return date.formatted(date: .omitted, time: .shortened) }
        if let days = calendar.dateComponents([.day], from: date, to: .now).day, days < 7 {
            return date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}
