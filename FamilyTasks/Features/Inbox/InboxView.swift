import SwiftUI
import MapKit

/// Requests waiting for me, plus updates on tasks I created (done / declined).
/// Location never appears here — creators only hear about completion.
struct InboxView: View {
    @EnvironmentObject private var store: FamilyStore
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var gate: PremiumGate

    var body: some View {
        let requests = store.incomingRequests
        let completed = store.completedForMe
        let declined = store.declinedForMe
        let edited = store.editedForMe
        let premiumRequests = store.premiumRequests
        let placeRequests = store.pendingPlaceRequests
        let myPlaceRequests = store.myPlaceRequests

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenTitle("Inbox").padding(.top, 8)

                if requests.isEmpty && completed.isEmpty && declined.isEmpty && edited.isEmpty && premiumRequests.isEmpty
                    && placeRequests.isEmpty && myPlaceRequests.isEmpty {
                    EmptyStateView(emoji: "📭", title: "You're all caught up",
                                   message: "Requests and updates on tasks you created show up here.")
                        .padding(.top, 40)
                }

                if !placeRequests.isEmpty {
                    SectionLabel("New places to check").padding(.top, 20).padding(.bottom, 4)
                    ForEach(placeRequests) { placeRequestCard($0) }
                }

                if !myPlaceRequests.isEmpty {
                    SectionLabel("Your place requests").padding(.top, 20).padding(.bottom, 4)
                    ForEach(myPlaceRequests) { myPlaceRequestRow($0) }
                }

                if !premiumRequests.isEmpty {
                    SectionLabel("Premium requests").padding(.top, 20).padding(.bottom, 4)
                    ForEach(premiumRequests) { premiumRow($0) }
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

                if !edited.isEmpty {
                    SectionLabel("Changed").padding(.top, 20).padding(.bottom, 4)
                    ForEach(edited) { task in
                        let who = task.editedByID.flatMap(store.member)
                        row(member: who, task: task, time: task.editedAt) {
                            Text("**\(who?.name ?? "Someone")** changed **\(task.title)** ✏️")
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
            .animation(Theme.spring, value: premiumRequests.map(\.id))
            .animation(Theme.spring, value: placeRequests.map(\.id))
            .animation(Theme.spring, value: myPlaceRequests.map(\.id))
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

    /// "Ali would like Stars & rewards ⭐" — Unlock opens the paywall (screen 9).
    private func premiumRow(_ request: PremiumRequest) -> some View {
        let who = store.member(request.memberID)
        return HStack(alignment: .top, spacing: 12) {
            if let who { AvatarView(member: who, size: 36) }
            VStack(alignment: .leading, spacing: 4) {
                Text("**\(who?.name ?? "Someone")** would like **\(request.feature.shortTitle)** \(request.feature.emoji)")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink)
                Text(request.date.formatted(.relative(presentation: .named)))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.ink3)
                HStack(spacing: 6) {
                    smallButton("Unlock", filled: true) { gate.present(for: request.feature, in: store) }
                    smallButton("Not now", filled: false) { store.dismissPremiumRequest(request.id) }
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
        .transition(.opacity.combined(with: .move(edge: .leading)))
    }

    // MARK: - Place requests

    /// 7g · A parent sees exactly where the child put the pin, then approves, edits or declines.
    private func placeRequestCard(_ request: PlaceRequest) -> some View {
        let who = store.member(request.memberID)
        let place = request.place
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                if let who { AvatarView(member: who, size: 36) }
                VStack(alignment: .leading, spacing: 3) {
                    Text("**\(who?.name ?? "Someone")** asked you to add a place")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.ink)
                    Text([request.date.formatted(.relative(presentation: .named)),
                          request.forTaskTitle.map { "for “\($0)”" }].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.ink3)
                }
            }
            RadiusMap(region: .constant(RadiusMap.region(around: place.coordinate, radius: place.radius)),
                      radius: place.radius, isInteractive: false, pinColor: Theme.urgent)
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("Map showing where \(who?.name ?? "they") put the pin")
            VStack(alignment: .leading, spacing: 2) {
                Text("\(place.emoji) **\(place.name)**\(place.address.isEmpty ? "" : " · \(place.address)")")
                if !request.hint.isEmpty { Text("“\(request.hint)”").foregroundStyle(Theme.ink2) }
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            HStack(spacing: 6) {
                smallButton("✓ Approve", filled: true, color: Theme.done) {
                    store.approvePlaceRequest(request.id)
                    Haptic.success.play()
                }
                smallButton("Edit", filled: false) { router.push(.reviewPlaceRequest(request.id)) }
                smallButton("Not now", filled: false) { store.declinePlaceRequest(request.id) }
            }
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.brand, lineWidth: 1.5))
        .padding(.vertical, 8)
        .transition(.opacity.combined(with: .move(edge: .leading)))
    }

    /// 7h · The child sees what happened to their request.
    private func myPlaceRequestRow(_ request: PlaceRequest) -> some View {
        let decider = request.decidedBy.flatMap(store.member)
        let place = request.place
        let (icon, tint, message): (String, Color, Text) = switch request.status {
        case .pending:
            ("⏳", Theme.highSoft, Text("Waiting for a parent to check **\(place.emoji) \(place.name)**"))
        case .approved:
            ("✅", Theme.doneSoft, Text("**\(place.emoji) \(place.name)** was added")
                + Text(decider.map { " by \($0.name)" } ?? "")
                + Text(". You can pick it for your tasks now."))
        case .declined:
            ("💬", Theme.surface2, Text("\(decider?.name ?? "A parent") said not now to **\(place.name)**"))
        }
        return HStack(alignment: .top, spacing: 12) {
            Text(icon)
                .font(.system(size: 17))
                .frame(width: 36, height: 36)
                .background(tint, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                message.font(.system(size: 14)).foregroundStyle(Theme.ink)
                Text((request.decidedAt ?? request.date).formatted(.relative(presentation: .named)))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.ink3)
                smallButton(request.status == .pending ? "Cancel request" : "OK", filled: false) {
                    store.dismissPlaceRequest(request.id)
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
        .transition(.opacity.combined(with: .move(edge: .leading)))
    }

    private func smallButton(_ title: String, filled: Bool, color: Color = Theme.ink,
                             action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Theme.spring, action)
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(filled ? .white : Theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(filled ? color : Theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}

#Preview {
    NavigationStack { InboxView() }.previewEnvironment()
}
