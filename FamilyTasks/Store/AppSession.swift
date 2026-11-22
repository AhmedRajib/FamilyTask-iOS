import UIKit
import Combine

/// Who is using this device and which family they're in. Drives the top-level screen:
/// Welcome (A1) → Create or join (A3) → the app.
final class AppSession: ObservableObject {
    enum Phase { case signedOut, needsFamily, ready }

    /// Apple / email login. Nil for a child who joined with an invite code only.
    @Published private(set) var account: Account?
    @Published private(set) var store: FamilyStore?
    /// Shown on the Welcome screen, e.g. after a parent signed this device out.
    @Published var notice: String?
    /// Code entered before signing in (an adult's invite). Used straight after sign-in.
    var pendingInviteCode: String?
    /// Set after creating a family, so the app opens "Add member" (A5) next.
    var shouldPromptAddMember = false

    private let server: LocalServer
    private let defaults: UserDefaults
    private var saved: Saved

    /// What this device remembers between launches.
    /// TODO: with the real backend, keep the device token in the Keychain instead.
    private struct Saved: Codable {
        var deviceID = UUID()
        var account: Account?
        var familyID: UUID?
        var memberID: UUID?
    }

    private static let key = "session"

    var phase: Phase {
        if store != nil { return .ready }
        return account == nil ? .signedOut : .needsFamily
    }

    init(server: LocalServer = .shared, defaults: UserDefaults = .standard) {
        self.server = server
        self.defaults = defaults
        if let raw = defaults.data(forKey: Self.key), let decoded = try? JSONDecoder().decode(Saved.self, from: raw) {
            saved = decoded
        } else {
            saved = Saved()
        }
        account = saved.account
        restore()
    }

    // MARK: - Sign in / out

    func signIn(_ account: Account) {
        self.account = account
        saved.account = account
        if let (stored, member) = server.membership(forAccount: account.id) {
            open(stored, as: member)
        } else if let code = pendingInviteCode {
            pendingInviteCode = nil
            do { try join(code: code) } catch { notice = error.localizedDescription }
        }
        persist()
    }

    func signOut(notice: String? = nil) {
        account = nil
        store = nil
        saved.account = nil
        saved.familyID = nil
        saved.memberID = nil
        self.notice = notice
        persist()
    }

    // MARK: - Family

    func createFamily(name: String, myName: String, colorHex: UInt32) {
        guard let account else { return }
        let me = Member(name: myName, role: .parent, colorHex: colorHex,
                        accountID: account.id, devices: [thisDevice])
        let stored = server.createFamily(name: name, owner: me)
        shouldPromptAddMember = true
        open(stored, as: me)
    }

    func lookupInvite(code: String) -> Result<(family: Family, member: Member), JoinError> {
        server.lookupInvite(code: code)
    }

    func join(code: String) throws {
        let (stored, member) = try server.acceptInvite(code: code, account: account, device: thisDevice)
        open(stored, as: member)
    }

    // MARK: - Email codes (local stand-in)

    func sendEmailCode(to email: String) -> String { server.sendEmailCode(to: email) }
    func verifyEmailCode(_ code: String, for email: String) -> Bool { server.verifyEmailCode(code, for: email) }

    #if DEBUG
    func resetEverything() {
        server.resetEverything()
        signOut()
    }
    #endif

    // MARK: - Private

    private var thisDevice: Device {
        Device(id: saved.deviceID, name: UIDevice.current.name, signedInAt: .now)
    }

    /// Re-opens the family on launch, unless a parent has signed this device out.
    private func restore() {
        guard let familyID = saved.familyID, let memberID = saved.memberID,
              let stored = server.family(id: familyID),
              let member = stored.family.members.first(where: { $0.id == memberID }) else {
            if let account, let (stored, member) = server.membership(forAccount: account.id) {
                open(stored, as: member)
            }
            return
        }
        guard server.isDeviceActive(saved.deviceID, member: memberID, family: familyID) else {
            signOut(notice: "This device was signed out by a parent. Ask them for a new invite code.")
            return
        }
        open(stored, as: member)
    }

    private func open(_ stored: StoredFamily, as member: Member) {
        server.register(device: thisDevice, member: member.id, family: stored.family.id)
        let fresh = server.family(id: stored.family.id) ?? stored
        let server = self.server
        store = FamilyStore(family: fresh.family, tasks: fresh.tasks, currentMemberID: member.id) { family, tasks in
            server.save(family: family, tasks: tasks)
        }
        saved.familyID = stored.family.id
        saved.memberID = member.id
        notice = nil
        persist()
    }

    private func persist() {
        if let raw = try? JSONEncoder().encode(saved) { defaults.set(raw, forKey: Self.key) }
    }
}

extension AppSession {
    /// In-memory session for SwiftUI previews.
    static var preview: AppSession {
        AppSession(server: LocalServer(fileURL: nil), defaults: UserDefaults(suiteName: "preview") ?? .standard)
    }
}
