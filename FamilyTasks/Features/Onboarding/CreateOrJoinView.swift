import SwiftUI

/// A3 · Shown once after the first sign-in, when the account isn't in a family yet.
struct CreateOrJoinView: View {
    @EnvironmentObject private var session: AppSession
    @State private var choice: Choice = .create
    @State private var path: [Choice] = []

    enum Choice: Hashable { case create, join }

    private var firstName: String {
        session.account?.name.split(separator: " ").first.map(String.init) ?? ""
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 12) {
                SetupTitle(
                    title: firstName.isEmpty ? "Welcome 👋" : "Welcome, \(firstName) 👋",
                    subtitle: "Let's get your family set up."
                )
                .padding(.top, 30)
                .padding(.bottom, 14)

                option(.create, icon: "🏡", title: "Create a family",
                       detail: "I'm setting it up. I'll invite everyone else.")
                option(.join, icon: "🔑", title: "Join a family",
                       detail: "Someone invited me and gave me a code.")

                Spacer()
                Button("Continue") { path.append(choice) }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Use a different login") { session.signOut() }
                    .font(.system(size: 14, weight: .medium))
                    .tint(Theme.ink2)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Choice.self) { choice in
                switch choice {
                case .create: CreateFamilyView()
                case .join: JoinFamilyView()
                }
            }
        }
    }

    private func option(_ value: Choice, icon: String, title: String, detail: String) -> some View {
        let isOn = choice == value
        return Button {
            withAnimation(.quick(0.25)) { choice = value }
        } label: {
            HStack(spacing: 14) {
                Text(icon)
                    .font(.system(size: 24))
                    .frame(width: 50, height: 50)
                    .background(isOn ? Theme.ink : Theme.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text(detail).font(.system(size: 13)).foregroundStyle(Theme.ink2)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isOn ? Theme.ink : Theme.line, lineWidth: isOn ? 2 : 1.5))
            .scaleEffect(isOn ? 1 : 0.98)
        }
        .buttonStyle(PressableStyle())
        .haptic(.selection, trigger: isOn)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A4 · Create a family. The creator becomes its first Parent.
struct CreateFamilyView: View {
    @EnvironmentObject private var session: AppSession
    @State private var myName = ""
    @State private var colorHex: UInt32 = Member.palette[0]
    @State private var familyName = ""
    @State private var didLoad = false

    private var canCreate: Bool {
        !myName.trimmingCharacters(in: .whitespaces).isEmpty && !familyName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                AvatarPreview(name: myName, colorHex: colorHex).padding(.top, 8)

                SectionLabel("Your name").padding(.top, 20).padding(.bottom, 8)
                TextField("First name", text: $myName)
                    .font(.system(size: 17, weight: .semibold))
                    .textContentType(.givenName)
                    .card()

                SectionLabel("Your colour").padding(.top, 20).padding(.bottom, 8)
                ColorChoiceRow(selection: $colorHex)

                SectionLabel("Family name").padding(.top, 20).padding(.bottom, 8)
                TextField("Our family", text: $familyName)
                    .font(.system(size: 17, weight: .semibold))
                    .card()

                Text("You'll be a 👑 Parent, so you can invite people and manage the family.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, 12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .navigationTitle("New family")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button("Create family") {
                session.createFamily(
                    name: familyName.trimmingCharacters(in: .whitespaces),
                    myName: myName.trimmingCharacters(in: .whitespaces),
                    colorHex: colorHex
                )
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canCreate)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Theme.background)
        }
        .onAppear(perform: prefill)
    }

    /// "Rajib Ahmed" → name "Rajib", family "The Ahmed Home".
    private func prefill() {
        guard !didLoad else { return }
        didLoad = true
        let parts = (session.account?.name ?? "").split(separator: " ").map(String.init)
        myName = parts.first ?? ""
        familyName = parts.count > 1 ? "The \(parts.last!) Home" : "Our Family"
    }
}

#Preview {
    CreateOrJoinView().environmentObject(AppSession.preview)
}
