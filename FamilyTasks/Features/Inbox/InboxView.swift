import SwiftUI

/// Requests waiting for me, plus updates on tasks I created (done / declined).
/// Location never appears here — creators only hear about completion.
struct InboxView: View {
    @EnvironmentObject private var store: FamilyStore
    @EnvironmentObject private var router: Router

    var body: some View {
        let requests = store.incomingRequests
        let completed = store.completedForMe
        let declined = store.declinedForMe

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenTitle("Inbox").padding(.top, 8)

                if requests.isEmpty && completed.isEmpty && declined.isEmpty {
                    EmptyStateView(emoji: "📭", title: "You're all caught up",
                                   message: "Requests and updates on tasks you created show up here.")
                        .padding(.top, 40)
                }

                if !requests.isEmpty {
                    SectionLabel("Needs your response").padding(.top, 20).padding(.bottom, 4)
                    ForEach(requests) { task in
                        let creator = store.member(task.creatorID)
                        row(member: creator, task: task, time: task.createdAt) {
                            Text("**\(creator?.name ?? "Someone")** asked you to **\(task.title)**")
                        } actions: {
                            HStack(spacing: 6) {
                                smallButton("Accept", filled: true) { store.accept(task.id) }
                                smallButton("Can't do it", filled: false) { store.decline(task.id, reason: nil) }
                            }
                        }
                    }
                }

                if !declined.isEmpty {
                    SectionLabel("Declined").padding(.top, 20).padding(.bottom, 4)
                    ForEach(declined) { task in
                        let who = task.assigneeIDs.first.flatMap(store.member)
                        row(member: who, task: task, time: nil) {
                            Text("**\(who?.name ?? "Someone")** can't do **\(task.title)**")
                            + Text(task.declineReason.map { ": “\($0)”" } ?? "")
                        } actions: { EmptyView() }
                    }
                }

                if !completed.isEmpty {
                    SectionLabel("Completed").padding(.top, 20).padding(.bottom, 4)
                    ForEach(completed) { task in
                        let who = task.completedByID.flatMap(store.member)
                        row(member: who, task: task, time: task.completedAt) {
                            Text("**\(who?.name ?? "Someone")** completed **\(task.title)** ✅")
                        } actions: { EmptyView() }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .animation(Theme.spring, value: requests.map(\.id))
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Inbox")
        .toolbar(.hidden, for: .navigationBar)
    }

    private func row<Message: View, Actions: View>(
        member: Member?, task: FamilyTask, time: Date?,
        @ViewBuilder message: () -> Message,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let member { AvatarView(member: member, size: 36) }
            VStack(alignment: .leading, spacing: 4) {
                message()
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink)
                if let time {
                    Text(time.formatted(.relative(presentation: .named)))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.ink3)
                }
                actions().padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
        .contentShape(Rectangle())
        .onTapGesture { router.push(.taskDetail(task.id)) }
        .transition(.opacity.combined(with: .move(edge: .leading)))
    }

    private func smallButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Theme.spring, action)
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(filled ? .white : Theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(filled ? Theme.ink : Theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}

#Preview {
    NavigationStack { InboxView() }.previewEnvironment()
}
