import SwiftUI
import AuthenticationServices

/// A1 · Welcome & sign in.
struct WelcomeView: View {
    @EnvironmentObject private var session: AppSession
    @State private var path: [AuthRoute] = []
    @State private var appeared = false
    @State private var errorMessage: String?
    @State private var showGoogleInfo = false

    enum AuthRoute: Hashable { case email, join }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                HeroArt(appeared: appeared)
                    .frame(height: 210)
                    .padding(.top, 36)
                    .padding(.bottom, 20)

                SetupTitle(
                    title: "Your family's to-do list",
                    subtitle: "Share tasks, set what's urgent, and get reminded at the right time and place.",
                    alignment: .center
                )
                .padding(.horizontal, 8)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

                if let notice = session.notice {
                    Text(notice)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.urgent)
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Theme.urgentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.top, 16)
                }

                Spacer(minLength: 20)
                buttons
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .email: EmailSignInView()
                case .join: JoinFamilyView()
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15)) { appeared = true }
            }
            .alert("Couldn't sign in", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Google sign-in", isPresented: $showGoogleInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Google sign-in is added together with the FamilyTasks server. Use Apple or email for now.")
            }
        }
    }

    private var buttons: some View {
        VStack(spacing: 9) {
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleApple(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            Button { showGoogleInfo = true } label: {
                HStack(spacing: 8) {
                    Text("G").font(.system(size: 17, weight: .heavy)).foregroundStyle(Color(hex: 0x4285F4))
                    Text("Continue with Google")
                }
            }
            .buttonStyle(OutlineButtonStyle())

            Button { path.append(.email) } label: {
                Label("Continue with email", systemImage: "envelope")
            }
            .buttonStyle(SecondaryButtonStyle())

            Button { path.append(.join) } label: {
                (Text("Got an invite code from your family? ").foregroundColor(Theme.ink2)
                 + Text("Join here").foregroundColor(Theme.brand).bold())
                    .font(.system(size: 14))
            }
            .padding(.top, 8)

            Text("By continuing you agree to the Terms and Privacy Policy.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.ink3)
                .padding(.top, 2)

            #if DEBUG
            Button("Explore the demo family") {
                session.signIn(LocalServer.demoAccount)
            }
            .font(.system(size: 13, weight: .semibold))
            .tint(Theme.ink2)
            .padding(.top, 6)
            #endif
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            // Apple only shares the name the first time someone signs in.
            let name = credential.fullName.map {
                PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
            } ?? ""
            session.signIn(Account(id: "apple:" + credential.user, name: name,
                                   email: credential.email, provider: .apple))
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = error.localizedDescription
        }
    }
}

/// White button with a grey outline (Continue with Google).
struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Theme.line, lineWidth: 1.5))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

/// Three task cards that drop in, then the first one ticks itself done.
private struct HeroArt: View {
    let appeared: Bool
    @State private var ticked = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            card("Feed the cat", avatar: "A", color: 0x2E9E6B, checked: ticked)
                .rotationEffect(.degrees(-4))
                .offset(x: 0, y: 10)
                .modifier(DropIn(appeared: appeared, delay: 0))
            card("⚡ Pick up Ali", avatar: "R", color: 0x3D7BD9, urgent: true)
                .rotationEffect(.degrees(2))
                .offset(x: 44, y: 76)
                .modifier(DropIn(appeared: appeared, delay: 0.1))
            card("📍 Milk at FreshMart", avatar: "N", color: 0xE86A92)
                .rotationEffect(.degrees(-2))
                .offset(x: 12, y: 142)
                .modifier(DropIn(appeared: appeared, delay: 0.2))
            Text("⭐")
                .font(.system(size: 34))
                .rotationEffect(.degrees(ticked ? 12 : -20))
                .scaleEffect(ticked ? 1 : 0.3)
                .opacity(ticked ? 1 : 0)
                .offset(x: 250, y: -4)
        }
        // Fixed, top-aligned box: the cards are positioned with offsets inside it.
        .frame(width: 290, height: 200, alignment: .topLeading)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
        .onChange(of: appeared) { _ in
            guard appeared else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { ticked = true }
            }
        }
    }

    private func card(_ title: String, avatar: String, color: UInt32, urgent: Bool = false, checked: Bool = false) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(checked ? Theme.done : .clear)
                RoundedRectangle(cornerRadius: 6).strokeBorder(checked ? Theme.done : Theme.line, lineWidth: 2)
                if checked {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                        .transition(.scale)
                }
            }
            .frame(width: 20, height: 20)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 4)
            Text(avatar)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color(hex: color), in: Circle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(width: 240)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
            .strokeBorder(urgent ? Theme.urgent : Theme.line, lineWidth: urgent ? 1.5 : 1))
        .shadow(color: (urgent ? Theme.urgent : .black).opacity(urgent ? 0.25 : 0.1), radius: 14, y: 8)
    }
}

private struct DropIn: ViewModifier {
    let appeared: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : -30)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(delay), value: appeared)
    }
}

#Preview {
    WelcomeView().environmentObject(AppSession.preview)
}
