import SwiftUI

/// A2 · Sign in with a 6-digit code sent by email. No passwords.
struct EmailSignInView: View {
    @EnvironmentObject private var session: AppSession
    @State private var email = ""
    @State private var sentTo: String?
    /// Only shown in debug builds, because there's no email server yet.
    @State private var demoCode: String?

    var body: some View {
        Group {
            if let sentTo {
                CodeEntry(email: sentTo, demoCode: demoCode) { resend() }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                emailStep.transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(Theme.spring, value: sentTo)
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isValid: Bool {
        let parts = email.trimmingCharacters(in: .whitespaces).split(separator: "@")
        return parts.count == 2 && parts[1].contains(".") && !parts[0].isEmpty
    }

    private var emailStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            iconTile("envelope.fill")
            SetupTitle(title: "What's your email?", subtitle: "We'll send you a 6-digit code. No password needed.")
                .padding(.top, 18)
            TextField("you@example.com", text: $email)
                .font(.system(size: 18, weight: .medium))
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.send)
                .onSubmit { if isValid { send() } }
                .card(padding: 16)
                .padding(.top, 24)
            Spacer()
            Button("Send code", action: send)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!isValid)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private func send() {
        let address = email.trimmingCharacters(in: .whitespaces).lowercased()
        let code = session.sendEmailCode(to: address)
        #if DEBUG
        demoCode = code
        #endif
        sentTo = address
    }

    private func resend() {
        guard let sentTo else { return }
        let code = session.sendEmailCode(to: sentTo)
        #if DEBUG
        demoCode = code
        #endif
    }
}

private func iconTile(_ systemName: String) -> some View {
    Image(systemName: systemName)
        .font(.system(size: 24))
        .foregroundStyle(Theme.brand)
        .frame(width: 58, height: 58)
        .background(Theme.brandSoft, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .padding(.top, 12)
}

/// Six boxes. Signs in as soon as the 6th digit is typed; a wrong code shakes and clears.
private struct CodeEntry: View {
    @EnvironmentObject private var session: AppSession
    let email: String
    let demoCode: String?
    let onResend: () -> Void

    @State private var code = ""
    @State private var isWrong = false
    @State private var shakes: CGFloat = 0
    @State private var resendAt = Date.now.addingTimeInterval(45)
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            iconTile("envelope.open.fill")
            SetupTitle(title: "Check your email", subtitle: "We sent a 6-digit code to \(email)")
                .padding(.top, 18)

            ZStack {
                // The real input: invisible, so iOS can autofill the code from Mail.
                TextField("", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($focused)
                    .opacity(0.02)
                    .onChange(of: code) { new in handle(new) }
                boxes
                    .contentShape(Rectangle())
                    .onTapGesture { focused = true }
            }
            .padding(.top, 26)
            .modifier(Shake(animatableData: shakes))

            Group {
                if isWrong {
                    Text("That code isn't right. Try again.").foregroundStyle(Theme.urgent)
                } else {
                    resendLine
                }
            }
            .font(.system(size: 14))
            .padding(.top, 16)

            #if DEBUG
            if let demoCode {
                Text("Demo: no email server yet, your code is **\(demoCode)**")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.highText)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.highSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 18)
            }
            #endif
            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear { focused = true }
        .haptic(.error, trigger: shakes)
    }

    private var boxes: some View {
        let digits = Array(code)
        return HStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { i in
                let isCurrent = i == digits.count && focused
                Text(i < digits.count ? String(digits[i]) : "")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(
                            isWrong ? Theme.urgent : (isCurrent ? Theme.brand : (i < digits.count ? Theme.ink3 : Theme.line)),
                            lineWidth: isCurrent || isWrong ? 2 : 1.5
                        )
                    )
                    .scaleEffect(i < digits.count ? 1 : 0.96)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: digits.count)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Code, \(code.count) of 6 digits entered")
    }

    private var resendLine: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = Int(resendAt.timeIntervalSince(context.date).rounded(.up))
            if left > 0 {
                Text("Didn't get it? ").foregroundColor(Theme.ink2)
                + Text("Resend in 0:\(String(format: "%02d", left))").foregroundColor(Theme.ink3)
            } else {
                Button {
                    onResend()
                    resendAt = .now.addingTimeInterval(45)
                } label: {
                    Text("Didn't get it? ").foregroundColor(Theme.ink2)
                    + Text("Resend code").foregroundColor(Theme.brand).bold()
                }
            }
        }
    }

    private func handle(_ new: String) {
        let digits = String(new.filter(\.isNumber).prefix(6))
        if digits != new { code = digits; return }
        if !digits.isEmpty { isWrong = false }
        guard digits.count == 6 else { return }

        if session.verifyEmailCode(digits, for: email) {
            focused = false
            let name = email.split(separator: "@").first.map { String($0).capitalized } ?? ""
            session.signIn(Account(id: "email:" + email, name: name, email: email, provider: .email))
        } else {
            isWrong = true
            withAnimation(.linear(duration: 0.4)) { shakes += 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { code = "" }
        }
    }
}

#Preview {
    NavigationStack { EmailSignInView() }.environmentObject(AppSession.preview)
}
