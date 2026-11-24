import SwiftUI

/// A8 · A member's profile. Parents manage role and devices here; everyone else just sees the
/// name and colour. Devices show only a name and date — never location or activity.
struct MemberProfileView: View {
    @EnvironmentObject private var store: FamilyStore
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var router: Router
    @Environment(\.dismiss) private var dismiss
    let memberID: UUID
    /// Tablet (expanded): shown beside the Family list instead of pushed, so it draws its own Edit button.
    var isPane = false

    @State private var confirm: Confirm?
    @State private var showEdit = false
    @State private var showLoginInfo = false

    private enum Confirm: Identifiable {
        case newPhone, signOutDevices, remove, signOutSelf
        var id: Self { self }
    }

    var body: some View {
        if let member = store.member(memberID) {
            content(member)
        } else {
            UnavailableView(title: "Member removed", systemImage: "person.crop.circle.badge.xmark")
        }
    }

    private var canManage: Bool { store.permissions.canManageMembers }
    private var isMe: Bool { memberID == store.me.id }

    private func content(_ member: Member) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if isPane && (canManage || isMe) {
                    HStack {
                        Spacer()
                        Button("Edit") { showEdit = true }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.brand)
                    }
                    .padding(.top, 12)
                }
                header(member)

                if canManage {
                    SectionLabel("Role").padding(.top, 22).padding(.bottom, 8)
                    RoleCards(
                        selection: Binding(
                            get: { member.role },
                            set: { role in withAnimation(Theme.spring) { store.setRole(member.id, to: role) } }
                        ),
                        showsBlurb: false,
                        isAllowed: { store.canChangeRole(of: member.id, to: $0) }
                    )
                    if member.role == .parent && store.parentCount <= 1 {
                        note("Every family needs at least one Parent.")
                    }
                }

                if canManage || isMe {
                    SectionLabel("Devices").padding(.top, 22).padding(.bottom, 8)
                    devices(member)
                }

                if canManage && member.accountID == nil && !member.isInvited {
                    SectionLabel("Login").padding(.top, 22).padding(.bottom, 8)
                    Button { showLoginInfo = true } label: {
                        DetailRow(icon: "key.fill", tint: Theme.purple, title: "Add a personal login",
                                  value: "Apple or email")
                    }
                    .buttonStyle(.plain)
                    .card(padding: 0)
                    note("For older kids, so they can sign in on any phone themselves.")
                }

                actions(member).padding(.top, 22)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .animation(Theme.spring, value: member)
        }
        .background(Theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            if canManage || isMe {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditMemberSheet(member: member) { name, color in
                store.updateMember(member.id, name: name, colorHex: color)
            }
        }
        .confirmationDialog(confirmTitle(member), isPresented: Binding(
            get: { confirm != nil }, set: { if !$0 { confirm = nil } }
        ), titleVisibility: .visible, presenting: confirm) { action in
            confirmButtons(action, member: member)
        } message: { action in
            Text(confirmMessage(action, member: member))
        }
        .alert("Personal login", isPresented: $showLoginInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Adding a personal login arrives with the FamilyTasks server.")
        }
    }

    // MARK: - Header

    private func header(_ member: Member) -> some View {
        let progress = store.weekProgress(for: member.id)
        let joined = member.devices.map(\.signedInAt).min()
        return HStack(spacing: 16) {
            AvatarView(member: member, size: 68)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(isMe ? "\(member.name) (you)" : member.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    if !canManage {
                        Pill(text: member.role.badge, foreground: Theme.ink2, background: Theme.surface2)
                    }
                }
                Group {
                    if member.isInvited {
                        Text("Invited · hasn't joined yet")
                    } else if let joined {
                        Text("Joined \(joined.formatted(.dateTime.day().month(.abbreviated))) · \(progress.done) done this week")
                    } else {
                        Text("\(progress.done) done this week")
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink2)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Devices

    private func devices(_ member: Member) -> some View {
        VStack(spacing: 0) {
            ForEach(member.devices) { device in
                HStack(spacing: 12) {
                    Image(systemName: device.name.localizedCaseInsensitiveContains("ipad") ? "ipad" : "iphone")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Theme.ink2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(device.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                        Text("Signed in since \(device.signedInAt.formatted(.dateTime.day().month(.abbreviated)))")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.ink3)
                    }
                    Spacer()
                    Pill(text: "Active", foreground: Theme.done, background: Theme.doneSoft)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                RowDivider()
            }

            if let invite = member.invite, !invite.isExpired, canManage {
                Button { router.push(.invite(memberID: member.id)) } label: {
                    DetailRow(icon: "qrcode", tint: Theme.high,
                              title: member.isInvited ? "Waiting to join" : "Invite pending",
                              value: "Show code")
                }
                .buttonStyle(.plain)
            } else if member.devices.isEmpty {
                DetailRow(icon: "iphone.slash", tint: Theme.ink3, title: "No devices", value: "", showsChevron: false)
            }

            if canManage && !member.isInvited {
                if member.invite == nil || member.invite!.isExpired { RowDivider() }
                Button {
                    store.newInvite(for: member.id, signOutDevices: false)
                    router.push(.invite(memberID: member.id))
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Theme.brand, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text("Add another device")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.brand)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .card(padding: 0)
    }

    // MARK: - Actions

    @ViewBuilder
    private func actions(_ member: Member) -> some View {
        let rows = actionRows(member)
        if !rows.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    Button { confirm = row.action } label: {
                        Text(row.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(row.destructive ? Theme.urgent : Theme.brand)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!row.enabled)
                    .opacity(row.enabled ? 1 : 0.4)
                    if index < rows.count - 1 { RowDivider(leading: 14) }
                }
            }
            .card(padding: 0)
            if member.role == .parent && store.parentCount <= 1 && canManage && !isMe {
                note("The only Parent can't be removed.")
            }
        }
    }

    private struct ActionRow {
        let title: String
        let action: Confirm
        var destructive = false
        var enabled = true
    }

    private func actionRows(_ member: Member) -> [ActionRow] {
        var rows: [ActionRow] = []
        if canManage && !isMe {
            if !member.isInvited {
                rows.append(ActionRow(title: "Set up a new phone", action: .newPhone))
                rows.append(ActionRow(title: "Sign out all devices", action: .signOutDevices, destructive: true))
            }
            rows.append(ActionRow(title: "Remove from family", action: .remove, destructive: true,
                                  enabled: store.canRemove(member.id)))
        }
        // Children can't sign themselves out, so they don't lock themselves out by accident.
        if isMe && member.role != .child {
            rows.append(ActionRow(title: "Sign out", action: .signOutSelf, destructive: true))
        }
        return rows
    }

    private func confirmTitle(_ member: Member) -> String {
        switch confirm {
        case .newPhone: "Set up a new phone for \(member.name)?"
        case .signOutDevices: "Sign out \(member.name) everywhere?"
        case .remove: "Remove \(member.name)?"
        case .signOutSelf: "Sign out?"
        case nil: ""
        }
    }

    private func confirmMessage(_ action: Confirm, member: Member) -> String {
        switch action {
        case .newPhone: "Their current phone is signed out, and you'll get a new code to scan on the new one."
        case .signOutDevices: "Every device signed in as \(member.name) stops working. You can invite them again later."
        case .remove: "Their profile is deleted. Tasks only they were doing are deleted too."
        case .signOutSelf: "You can sign back in any time with the same login."
        }
    }

    @ViewBuilder
    private func confirmButtons(_ action: Confirm, member: Member) -> some View {
        switch action {
        case .newPhone:
            Button("Sign out old phone & show code") {
                store.newInvite(for: member.id, signOutDevices: true)
                router.push(.invite(memberID: member.id))
            }
        case .signOutDevices:
            Button("Sign out everywhere", role: .destructive) {
                withAnimation(Theme.spring) { store.signOutAllDevices(of: member.id) }
            }
        case .remove:
            Button("Remove \(member.name)", role: .destructive) {
                if isPane { router.selectedMember = nil } else { dismiss() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { store.removeMember(member.id) }
            }
        case .signOutSelf:
            Button("Sign out", role: .destructive) { session.signOut() }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.ink3)
            .padding(.horizontal, 4)
            .padding(.top, 8)
    }
}

/// Name and colour.
private struct EditMemberSheet: View {
    let member: Member
    let onSave: (String, UInt32) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var colorHex: UInt32 = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AvatarPreview(name: name, colorHex: colorHex).padding(.top, 8)
                SectionLabel("Name").padding(.top, 20).padding(.bottom, 8)
                TextField("Name", text: $name).font(.system(size: 17, weight: .semibold)).card()
                SectionLabel("Colour").padding(.top, 20).padding(.bottom, 8)
                ColorChoiceRow(selection: $colorHex)
                Spacer()
            }
            .padding(20)
            .background(Theme.background)
            .navigationTitle("Edit \(member.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name.trimmingCharacters(in: .whitespaces), colorHex)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            name = member.name
            colorHex = member.colorHex
        }
    }
}

#Preview {
    let store = FamilyStore.preview()
    return NavigationStack { MemberProfileView(memberID: store.family.members[3].id) }
        .environmentObject(store)
        .environmentObject(Router())
        .environmentObject(AppSession.preview)
}
