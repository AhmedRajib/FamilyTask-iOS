import SwiftUI

struct FamilyView: View {
    @EnvironmentObject private var store: FamilyStore
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var gate: PremiumGate
    @EnvironmentObject private var session: AppSession
    @State private var appeared = false

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
                .reveal(appeared, order: 0, distance: -10)

                HouseholdCard(isShown: appeared)
                    .padding(.top, 14)
                    .reveal(appeared, order: 1)

                VStack(spacing: 0) {
                    if store.permissions.canPay || store.isPremium {
                        Button(action: premiumTapped) {
                            DetailRow(icon: "sparkles", tint: Theme.high, title: "Family Premium",
                                      value: premiumValue,
                                      valueColor: store.isPremium ? Theme.done : Theme.highText,
                                      showsChevron: store.permissions.canPay)
                        }
                        .buttonStyle(.plain)
                        .disabled(!store.permissions.canPay)
                        RowDivider()
                    }
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
                .reveal(appeared, order: 3)

                HStack {
                    Text("This week").font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text("done / total").font(.system(size: 12)).foregroundStyle(Theme.ink3)
                }
                .padding(.bottom, 8)
                .reveal(appeared, order: 4)

                VStack(spacing: 0) {
                    ForEach(Array(store.family.members.enumerated()), id: \.element.id) { index, member in
                        Button { router.push(.memberProfile(member.id)) } label: {
                            MemberRow(member: member, isMe: member.id == store.me.id,
                                      progress: store.weekProgress(for: member.id),
                                      isShown: appeared,
                                      fillDelay: 0.35 + Double(min(index, 10)) * 0.07)
                        }
                        .buttonStyle(.plain)
                        .reveal(appeared, order: 5 + index, distance: 14)
                        if index < store.family.members.count - 1 { RowDivider(leading: 70) }
                    }
                }
                .card(padding: 0)
                .reveal(appeared, order: 5, distance: 20)
                .animation(Theme.spring, value: store.family.members.map(\.id))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .startsEntrance($appeared, isActive: router.tab == .family)
        .navigationTitle("Family")
        .toolbar(.hidden, for: .navigationBar)
    }

    private var premiumValue: String {
        guard let premium = store.family.premium, premium.isActive else { return "Upgrade" }
        return premium.isTrial
            ? "Trial until \(premium.expiresAt.formatted(.dateTime.day().month(.abbreviated)))"
            : "Active"
    }

    /// Parents: manage the subscription if there is one, otherwise open the paywall.
    private func premiumTapped() {
        if store.isPremium {
            Task { await PremiumStore.shared.showManageSubscriptions() }
        } else {
            gate.present(for: nil, in: store)
        }
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
    /// Bars fill one after another as the rows arrive.
    /// The row is on screen (the Family tab's entrance has started).
    var isShown = true
    var fillDelay: Double = 0.1

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
                                .frame(width: proxy.size.width * (isShown ? fraction : 0))
                                .animation(.spring(response: 0.8, dampingFraction: 0.85).delay(fillDelay), value: isShown)
                                .animation(Theme.spring, value: fraction)
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
