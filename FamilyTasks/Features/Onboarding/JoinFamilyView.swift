import SwiftUI

/// A7 · Join with an invite code (scanned or typed). The code decides the family, the profile and
/// the role. Children join without a login; adults sign in first so they can get back in later.
struct JoinFamilyView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var scanned = false
    @State private var joinError: String?
    @FocusState private var focused: Bool

    private var normalised: String { LocalServer.normalise(code) }

    private var lookup: Result<(family: Family, member: Member), JoinError>? {
        normalised.count == 8 ? session.lookupInvite(code: code) : nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                scannerBox

                SectionLabel("or enter the code")
                    .multilineTextAlignment(.center)
                    .padding(.top, 18)
                    .padding(.bottom, 8)
                TextField("XXXX-XXXX", text: $code)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .onChange(of: code) { new in format(new) }
                    .card(padding: 14)

                result
                    .padding(.top, 14)
                    .animation(Theme.spring, value: normalised)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .navigationTitle("Join a family")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) { joinButton }
        .alert("Couldn't join", isPresented: Binding(get: { joinError != nil }, set: { if !$0 { joinError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(joinError ?? "")
        }
        .haptic(.success, trigger: scanned)
    }

    // MARK: - Scanner

    @ViewBuilder
    private var scannerBox: some View {
        ZStack(alignment: .bottom) {
            if CodeScannerView.isAvailable && !scanned {
                CodeScannerView { found in
                    code = found
                    scanned = true
                    focused = false
                }
            } else {
                Color(hex: 0x2A2723)
                VStack(spacing: 8) {
                    Image(systemName: scanned ? "checkmark.circle.fill" : "qrcode.viewfinder")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(scanned ? Theme.done : .white.opacity(0.85))
                    Text(scanned ? "Code scanned" : "Camera isn't available here. Type the code below.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .frame(maxHeight: .infinity)
            }
            if !scanned && CodeScannerView.isAvailable {
                Text("📷 Point at the QR code on their phone")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(.bottom, 12)
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.top, 8)
        .animation(Theme.spring, value: scanned)
    }

    // MARK: - Preview of who you'll be

    @ViewBuilder
    private var result: some View {
        switch lookup {
        case .success(let found):
            InvitePreview(family: found.family, member: found.member)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
        case .failure(let error):
            Text(error.localizedDescription)
                .font(.system(size: 14))
                .foregroundStyle(Theme.urgent)
                .multilineTextAlignment(.center)
                .transition(.opacity)
        case nil:
            #if DEBUG
            Text("Demo: try code **\(LocalServer.demoInviteCode)** to join the demo family as Nana.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)
            #else
            EmptyView()
            #endif
        }
    }

    // MARK: - Join

    /// Adults and parents need their own login before joining; children don't.
    private var needsSignIn: Bool {
        guard case .success(let found) = lookup else { return false }
        return session.account == nil && found.member.role != .child
    }

    @ViewBuilder
    private var joinButton: some View {
        VStack(spacing: 8) {
            if needsSignIn {
                Text("Sign in first, so you can get back in on a new phone.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
            }
            Button(buttonTitle, action: join)
                .buttonStyle(PrimaryButtonStyle(color: needsSignIn ? Theme.ink : Theme.done))
                .disabled(!lookupSucceeded)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Theme.background)
        .animation(.quick, value: needsSignIn)
    }

    private var lookupSucceeded: Bool {
        if case .success = lookup { return true }
        return false
    }

    private var buttonTitle: String {
        guard case .success(let found) = lookup else { return "Join family" }
        return needsSignIn ? "Sign in to join" : "Join \(found.family.name)"
    }

    private func join() {
        if needsSignIn {
            // Back to the sign-in buttons; the code is used as soon as they've signed in.
            session.pendingInviteCode = code
            dismiss()
            return
        }
        do {
            try session.join(code: code)
        } catch {
            joinError = error.localizedDescription
        }
    }

    /// Keeps the field as "XXXX-XXXX".
    private func format(_ new: String) {
        let raw = String(LocalServer.normalise(new).prefix(8))
        let formatted = raw.count > 4 ? raw.prefix(4) + "-" + raw.dropFirst(4) : Substring(raw)
        if String(formatted) != new { code = String(formatted) }
    }
}

private struct InvitePreview: View {
    let family: Family
    let member: Member

    private var inviter: [Member] { family.members.filter { $0.role == .parent && !$0.isInvited } }

    var body: some View {
        VStack(spacing: 6) {
            AvatarStack(members: Array(family.members.filter { !$0.isInvited }.prefix(4)), size: 34)
            Text("\(inviter.first?.name ?? "Your family") invited you to")
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink2)
                .padding(.top, 4)
            Text("\(family.name) 🏡")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Theme.ink)
            HStack(spacing: 7) {
                AvatarView(member: member, size: 24)
                Text("You'll join as ").foregroundColor(Theme.ink2)
                + Text("\(member.name) · \(member.role.title)").bold().foregroundColor(Theme.ink)
            }
            .font(.system(size: 14))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(Theme.doneSoft, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .padding(.top, 8)
        }
        .card(padding: 16)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack { JoinFamilyView() }.environmentObject(AppSession.preview)
}
