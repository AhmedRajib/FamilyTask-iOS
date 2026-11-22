import Foundation

/// A family and its tasks, as the server stores them.
struct StoredFamily: Codable {
    var family: Family
    var tasks: [FamilyTask]
}

enum JoinError: LocalizedError {
    case notFound, expired, alreadyInFamily

    var errorDescription: String? {
        switch self {
        case .notFound: "That code doesn't match an invite. Check it with the person who invited you."
        case .expired: "This invite has expired. Ask for a new one."
        case .alreadyInFamily: "You're already in a family with this login."
        }
    }
}

/// Stand-in for the FamilyTasks API until the real backend exists. That backend is
/// FamilyTasks' own — it never talks to SafeguardNote's server.
///
/// Everything lives in one JSON file on this device. A family created here can also be joined
/// here: add a member, sign out, then join with their code. Replace this with an API client
/// that has the same methods once the server is built.
final class LocalServer {
    static let shared = LocalServer(
        fileURL: URL.applicationSupportDirectory.appending(path: "FamilyTasks/local-server.json")
    )

    private struct Contents: Codable {
        var families: [StoredFamily] = []
    }

    private let fileURL: URL?
    private var contents: Contents
    /// Email sign-in codes waiting to be checked: email → code.
    private var pendingEmailCodes: [String: String] = [:]

    init(fileURL: URL?) {
        self.fileURL = fileURL
        if let fileURL,
           let raw = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(Contents.self, from: raw) {
            contents = decoded
        } else {
            contents = Contents()
        }
        seedDemoFamilyIfNeeded()
    }

    // MARK: - Families

    func family(id: UUID) -> StoredFamily? {
        contents.families.first { $0.family.id == id }
    }

    /// The family and member an Apple / email login belongs to.
    func membership(forAccount accountID: String) -> (StoredFamily, Member)? {
        for stored in contents.families {
            if let member = stored.family.members.first(where: { $0.accountID == accountID }) {
                return (stored, member)
            }
        }
        return nil
    }

    func createFamily(name: String, owner: Member) -> StoredFamily {
        let stored = StoredFamily(
            family: Family(name: name, members: [owner], places: [], times: Self.starterTimes, templates: []),
            tasks: []
        )
        contents.families.append(stored)
        persist()
        return stored
    }

    func save(family: Family, tasks: [FamilyTask]) {
        guard let i = contents.families.firstIndex(where: { $0.family.id == family.id }) else { return }
        contents.families[i] = StoredFamily(family: family, tasks: tasks)
        persist()
    }

    // MARK: - Devices

    func register(device: Device, member memberID: UUID, family familyID: UUID) {
        guard let f = contents.families.firstIndex(where: { $0.family.id == familyID }),
              let m = contents.families[f].family.members.firstIndex(where: { $0.id == memberID }),
              !contents.families[f].family.members[m].devices.contains(where: { $0.id == device.id })
        else { return }
        contents.families[f].family.members[m].devices.append(device)
        persist()
    }

    /// False once a parent signs the device out (or removes the member).
    func isDeviceActive(_ deviceID: UUID, member memberID: UUID, family familyID: UUID) -> Bool {
        family(id: familyID)?.family.members
            .first { $0.id == memberID }?
            .devices.contains { $0.id == deviceID } ?? false
    }

    // MARK: - Invites

    /// The family and member behind a code, for the "You'll join as Ali · Child" preview.
    func lookupInvite(code: String) -> Result<(family: Family, member: Member), JoinError> {
        guard let (f, m) = locate(code: code) else { return .failure(.notFound) }
        let member = contents.families[f].family.members[m]
        if member.invite?.isExpired ?? true { return .failure(.expired) }
        return .success((contents.families[f].family, member))
    }

    /// Uses the code: the device is signed in as that member, with the member's role.
    /// An Apple / email login is attached too when there is one. The code can't be used again.
    func acceptInvite(code: String, account: Account?, device: Device) throws -> (StoredFamily, Member) {
        guard let (f, m) = locate(code: code) else { throw JoinError.notFound }
        if contents.families[f].family.members[m].invite?.isExpired ?? true { throw JoinError.expired }
        if let account, membership(forAccount: account.id) != nil { throw JoinError.alreadyInFamily }

        contents.families[f].family.members[m].invite = nil
        contents.families[f].family.members[m].devices.append(device)
        if let account { contents.families[f].family.members[m].accountID = account.id }
        persist()
        return (contents.families[f], contents.families[f].family.members[m])
    }

    private func locate(code: String) -> (Int, Int)? {
        let wanted = Self.normalise(code)
        guard !wanted.isEmpty else { return nil }
        for f in contents.families.indices {
            if let m = contents.families[f].family.members.firstIndex(where: {
                $0.invite.map { Self.normalise($0.code) } == wanted
            }) {
                return (f, m)
            }
        }
        return nil
    }

    /// 8 characters without look-alikes (no 0/O, 1/I), shown as "K7Q2-M9XA".
    static func makeInvite(validFor days: Int = 7) -> Invite {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let chars = (0..<8).map { _ in alphabet.randomElement()! }
        let code = String(chars[0..<4]) + "-" + String(chars[4..<8])
        let expires = Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now
        return Invite(code: code, expiresAt: expires)
    }

    /// Upper-case letters and digits only, so "k7q2 m9xa" matches "K7Q2-M9XA".
    static func normalise(_ code: String) -> String {
        code.uppercased().filter { ($0.isLetter || $0.isNumber) && $0.isASCII }
    }

    // MARK: - Email sign-in

    /// The real server emails this. Locally it's returned so the screen can show it.
    func sendEmailCode(to email: String) -> String {
        let code = String(format: "%06d", Int.random(in: 0...999_999))
        pendingEmailCodes[email.lowercased()] = code
        return code
    }

    func verifyEmailCode(_ code: String, for email: String) -> Bool {
        guard pendingEmailCodes[email.lowercased()] == code else { return false }
        pendingEmailCodes[email.lowercased()] = nil
        return true
    }

    // MARK: - Demo data

    static let demoInviteCode = "NANA-2026"
    static let demoAccount = Account(id: "demo-rajib", name: "Rajib Ahmed", email: nil, provider: .demo)

    /// Puts the sample "Ahmed Home" family here once, so there's something to explore and an
    /// invite (Nana's, code NANA-2026) to test joining with.
    private func seedDemoFamilyIfNeeded() {
        guard membership(forAccount: Self.demoAccount.id) == nil else { return }
        let sample = SampleData.make()
        contents.families.append(StoredFamily(family: sample.family, tasks: sample.tasks))
        persist()
    }

    func resetEverything() {
        contents = Contents()
        seedDemoFamilyIfNeeded()
    }

    private static var starterTimes: [TimeShortcut] {
        [
            TimeShortcut(name: "Before school", emoji: "🎒", hour: 7, minute: 30),
            TimeShortcut(name: "After school", emoji: "🏫", hour: 15, minute: 30),
            TimeShortcut(name: "Dinner", emoji: "🍽️", hour: 19, minute: 0),
            TimeShortcut(name: "Bedtime", emoji: "🌙", hour: 21, minute: 0),
        ]
    }

    // MARK: - Saving

    private func persist() {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(contents).write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            print("FamilyTasks: local server save failed – \(error)")
        }
    }
}
