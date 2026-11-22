import SwiftUI

struct FamilyView: View {
    @EnvironmentObject private var store: FamilyStore
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var session: AppSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    ScreenTitle("Family")
                    Spacer()
                    #if DEBUG
                    debugMenu
                    #endif
                }
                .padding(.top, 8)

                householdCard.padding(.top, 14)

                VStack(spacing: 0) {
                    Button { router.push(.shortcuts) } label: {
                        DetailRow(
                            icon: "bolt.fill", tint: Theme.high, title: "Shortcuts",
                            value: "\(store.family.templates.count) tasks · \(store.family.places.count) places"
                        )
                    }
                    .buttonStyle(.plain)
                    RowDivider()
                    Button { router.push(.sounds) } label: {
                        DetailRow(icon: "speaker.wave.2.fill", tint: Theme.purple, title: "Sounds",
                                  value: ToneLibrary.name(of: SoundSettings.shared.notificationToneID))
                    }
                    .buttonStyle(.plain)
                }
                .card(padding: 0)
                .padding(.vertical, 16)

                HStack {
                    Text("This week").font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text("done / total").font(.system(size: 12)).foregroundStyle(Theme.ink3)
                }
                .padding(.bottom, 8)

                VStack(spacing: 0) {
                    ForEach(Array(store.family.members.enumerated()), id: \.element.id) { index, member in
                        Button { router.push(.memberProfile(member.id)) } label: {
                            MemberRow(member: member, isMe: member.id == store.me.id,
                                      progress: store.weekProgress(for: member.id))
                        }
                        .buttonStyle(.plain)
                        if index < store.family.members.count - 1 { RowDivider(leading: 70) }
                    }
                }
                .card(padding: 0)
                .animation(Theme.spring, value: store.family.members.map(\.id))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("Family")
        .toolbar(.hidden, for: .navigationBar)
    }

    private var householdCard: some View {
        let joined = store.family.members.filter { !$0.isInvited }
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Household").font(.system(size: 12)).opacity(0.6)
                    Text("\(store.family.name) 🏡").font(.system(size: 19, weight: .bold))
                }
                Spacer()
                AvatarStack(members: Array(joined.prefix(4)), size: 32, ring: Theme.ink)
            }
            if store.permissions.canManageMembers {
                Button { router.push(.addMember) } label: {
                    Label("Add member", systemImage: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(PressableStyle())
            }
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(Theme.ink, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    #if DEBUG
    /// Test tools: look at the app as another member (to check permissions), or start over.
    private var debugMenu: some View {
        Menu {
            Picker("Use the app as", selection: Binding(
                get: { store.currentMemberID },
                set: { id in withAnimation(Theme.spring) { store.switchUser(to: id) } }
            )) {
                ForEach(store.family.members) { member in
                    Text("\(member.name) · \(member.role.title)").tag(member.id)
                }
            }
            Button("Sign out") { session.signOut() }
            Button("Reset everything", role: .destructive) { session.resetEverything() }
        } label: {
            Label("Debug", systemImage: "ladybug")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Theme.surface2, in: Capsule())
        }
        .tint(Theme.ink2)
    }
    #endif
}

private struct MemberRow: View {
    let member: Member
    let isMe: Bool
    let progress: (done: Int, total: Int)
    @State private var appeared = false

    private var fraction: Double {
        progress.total == 0 ? 0 : Double(progress.done) / Double(progress.total)
    }

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(member: member, size: 44)
                .opacity(member.isInvited ? 0.5 : 1)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(isMe ? "\(member.name) (you)" : member.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    if member.isInvited {
                        Pill(text: "Invited", foreground: Theme.low, background: Theme.lowSoft)
                    } else {
                        Pill(text: member.role.badge,
                             foreground: member.role == .parent ? Theme.highText : Theme.ink2,
                             background: member.role == .parent ? Theme.highSoft : Theme.surface2)
                    }
                }
                if member.isInvited {
                    Text("Waiting to join").font(.system(size: 12)).foregroundStyle(Theme.ink3)
                } else {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.surface2)
                            Capsule()
                                .fill(member.color)
                                .frame(width: proxy.size.width * (appeared ? fraction : 0))
                        }
                    }
                    .frame(height: 6)
                }
            }
            if member.isInvited {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            } else {
                Text("\(progress.done)/\(progress.total)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(minWidth: 40, alignment: .trailing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.1)) { appeared = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(member.isInvited
            ? "\(member.name), invited, waiting to join"
            : "\(member.name), \(member.role.title), \(progress.done) of \(progress.total) done this week")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    NavigationStack { FamilyView() }.previewEnvironment()
}
