import SwiftUI

/// A5 · A parent creates the profile (name, role, colour). The role is decided here, never by
/// the person joining. Next comes their invite (A6).
struct AddMemberView: View {
    @EnvironmentObject private var store: FamilyStore
    @EnvironmentObject private var router: Router
    @State private var name = ""
    @State private var role: Role = .child
    @State private var colorHex: UInt32 = Member.palette[3]
    @State private var didLoad = false
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                AvatarPreview(name: name, colorHex: colorHex).padding(.top, 8)

                SectionLabel("Name").padding(.top, 20).padding(.bottom, 8)
                TextField("e.g. Ali", text: $name)
                    .font(.system(size: 17, weight: .semibold))
                    .textContentType(.givenName)
                    .focused($focused)
                    .submitLabel(.done)
                    .card()

                SectionLabel("Who are they?").padding(.top, 20).padding(.bottom, 8)
                RoleCards(selection: $role)

                SectionLabel("Colour").padding(.top, 20).padding(.bottom, 8)
                ColorChoiceRow(selection: $colorHex)

                Text(roleExplanation)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, 12)
                    .contentTransition(.opacity)
                    .animation(.quick, value: role)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .navigationTitle("Add member")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(trimmed.isEmpty ? "Create invite" : "Create \(trimmed)'s invite", action: create)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(trimmed.isEmpty || !store.permissions.canManageMembers)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Theme.background)
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            // Start with a colour nobody uses yet.
            let used = Set(store.family.members.map(\.colorHex))
            colorHex = Member.palette.first { !used.contains($0) } ?? Member.palette[0]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { focused = true }
        }
    }

    private var roleExplanation: String {
        switch role {
        case .parent: "Parents can do everything: invite people, change roles and manage Premium."
        case .adult: "Adults can create and assign tasks to anyone, but can't manage the family."
        case .child: "Children can create their own tasks and ask adults for help. No email needed. Their invite code signs them in."
        }
    }

    private func create() {
        guard let member = store.addMember(name: trimmed, role: role, colorHex: colorHex) else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        router.replaceTop(with: .invite(memberID: member.id))
    }
}

/// A6 · The QR code and one-time code that sign a device in as this member.
struct InviteView: View {
    @EnvironmentObject private var store: FamilyStore
    let memberID: UUID
    @State private var copied = false
    @State private var appeared = false

    var body: some View {
        if let member = store.member(memberID) {
            if let invite = member.invite, !invite.isExpired {
                content(member: member, invite: invite)
            } else if member.isInvited {
                UnavailableView(title: "Invite expired", systemImage: "clock.badge.xmark",
                                message: "Create a new one from \(member.name)'s profile.")
            } else {
                UnavailableView(title: "\(member.name) has joined 🎉", systemImage: "checkmark.circle",
                                message: "They're signed in and ready to go.")
            }
        }
    }

    private func content(member: Member, invite: Invite) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                (Text("On \(member.name)'s phone, open FamilyTasks → ")
                 + Text("Join a family").bold()
                 + Text(", then scan this code."))
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                QRCodeView(text: InvitePayload.encode(invite.code))
                    .frame(width: 190, height: 190)
                    .padding(18)
                    .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.line))
                    .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
                    .scaleEffect(appeared ? 1 : 0.85)
                    .opacity(appeared ? 1 : 0)
                    .padding(.top, 20)

                SectionLabel("or type this code")
                    .multilineTextAlignment(.center)
                    .padding(.top, 22)
                Text(invite.code)
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Theme.ink)
                    .textSelection(.enabled)
                    .padding(.top, 6)
                Text("Works once · expires \(invite.expiresAt.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink3)
                    .padding(.top, 4)
                Text("\(member.name) will join as \(member.role.emoji) \(member.role.title).")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink2)
                    .padding(.top, 14)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle("Invite \(member.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = invite.code
                    withAnimation(.quick) { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation(.quick) { copied = false } }
                } label: {
                    Label(copied ? "Copied" : "Copy code", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(SecondaryButtonStyle())
                .haptic(.success, trigger: copied) { _, new in new }

                ShareLink(item: shareText(member: member, invite: invite)) {
                    Label("Share invite", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Theme.background)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) { appeared = true }
        }
    }

    private func shareText(member: Member, invite: Invite) -> String {
        "Join \(store.family.name) on FamilyTasks! Open the app, tap \"Join a family\" and enter this code: \(invite.code)\n(It works once and expires in 7 days.)"
    }
}

#Preview {
    NavigationStack { AddMemberView() }.previewEnvironment()
}
