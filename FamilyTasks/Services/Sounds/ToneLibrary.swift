import AVFoundation
import UserNotifications

/// Which sound a tone is used for.
enum ToneKind: String, Codable, Hashable {
    /// Reminders and updates ("Ali completed…").
    case notification
    /// Urgent tasks, which ring like a call.
    case ringtone

    var title: String { self == .notification ? "Notification sound" : "Urgent ringtone" }
}

struct Tone: Identifiable, Hashable {
    let id: String
    let name: String
    let isCustom: Bool
    var duration: TimeInterval? = nil
}

/// Built-in tones (generated on the device, no audio files to ship) plus sounds the user imports.
/// Approach adapted from SafeguardNote's RingtonePlayer / CustomToneStore — copied, not shared.
///
/// iOS only plays a custom notification sound if it lives in `Library/Sounds/`, is under 30
/// seconds and is in a format like PCM `.caf`, so imports are converted and trimmed.
enum ToneLibrary {
    static let systemID = "system"
    static let silentID = "silent"

    /// iOS falls back to the default sound for custom sounds of 30 s or longer.
    static let maxDuration: TimeInterval = 29

    // MARK: - Built-in catalogue

    struct Note { let frequency: Double; let duration: Double; let gap: Double }

    /// Ringtones end with a longer gap so they read as separate rings when repeated.
    private static let catalog: [(name: String, kind: ToneKind, notes: [Note])] = [
        ("Chime", .notification, [Note(frequency: 880, duration: 0.16, gap: 0.05), Note(frequency: 1318, duration: 0.30, gap: 0)]),
        ("Pebble", .notification, [Note(frequency: 660, duration: 0.09, gap: 0)]),
        ("Ripple", .notification, [Note(frequency: 1046, duration: 0.11, gap: 0.04), Note(frequency: 880, duration: 0.11, gap: 0.04),
                                   Note(frequency: 698, duration: 0.20, gap: 0)]),
        ("Ding Dong", .notification, [Note(frequency: 784, duration: 0.25, gap: 0.05), Note(frequency: 622, duration: 0.40, gap: 0)]),
        ("Classic", .ringtone, [Note(frequency: 880, duration: 0.32, gap: 0.12), Note(frequency: 880, duration: 0.32, gap: 0.6)]),
        ("Beacon", .ringtone, [Note(frequency: 740, duration: 0.20, gap: 0.15), Note(frequency: 740, duration: 0.20, gap: 0.15),
                               Note(frequency: 740, duration: 0.20, gap: 0.6)]),
        ("Pulse", .ringtone, [Note(frequency: 523, duration: 0.09, gap: 0.07), Note(frequency: 523, duration: 0.09, gap: 0.07),
                              Note(frequency: 523, duration: 0.09, gap: 0.6)]),
        ("Escalating", .ringtone, [Note(frequency: 494, duration: 0.13, gap: 0.03), Note(frequency: 587, duration: 0.13, gap: 0.03),
                                   Note(frequency: 698, duration: 0.13, gap: 0.03), Note(frequency: 880, duration: 0.22, gap: 0.6)]),
    ]

    /// Ringtones are repeated inside the file, so the notification keeps ringing for a while.
    private static let ringRepeats = 8

    static func builtIns(_ kind: ToneKind) -> [Tone] {
        var tones = [Tone(id: systemID, name: "iPhone default", isCustom: false)]
        if kind == .notification { tones.append(Tone(id: silentID, name: "Silent", isCustom: false)) }
        tones += catalog.filter { $0.kind == kind }.map { Tone(id: $0.name, name: $0.name, isCustom: false) }
        return tones
    }

    static func tone(id: String) -> Tone? {
        (builtIns(.notification) + builtIns(.ringtone) + customTones(.notification) + customTones(.ringtone))
            .first { $0.id == id }
    }

    static func name(of id: String) -> String { tone(id: id)?.name ?? "iPhone default" }

    // MARK: - Playing

    /// The sound file for a tone, creating built-in files the first time. Nil for system/silent.
    static func fileURL(for id: String) -> URL? {
        if let record = customRecords(.notification).first(where: { $0.fileName == id })
            ?? customRecords(.ringtone).first(where: { $0.fileName == id }) {
            let url = soundsDirectory.appendingPathComponent(record.fileName)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        guard let entry = catalog.first(where: { $0.name == id }) else { return nil }
        let url = soundsDirectory.appendingPathComponent(builtInFileName(entry.name))
        if !FileManager.default.fileExists(atPath: url.path) {
            let notes = entry.kind == .ringtone
                ? Array(repeating: entry.notes, count: ringRepeats).flatMap { $0 }
                : entry.notes
            try? write(notes, to: url)
        }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// For `UNMutableNotificationContent.sound`. Nil means silent.
    static func notificationSound(for id: String) -> UNNotificationSound? {
        if id == silentID { return nil }
        guard let url = fileURL(for: id) else { return .default }
        return UNNotificationSound(named: UNNotificationSoundName(url.lastPathComponent))
    }

    // MARK: - Importing from the device

    enum ImportError: LocalizedError {
        case unreadable, protected

        var errorDescription: String? {
            switch self {
            case .unreadable: "That file isn't a sound FamilyTasks can use. Try an MP3, M4A, WAV or AIFF file."
            case .protected: "That song is copy-protected (for example from Apple Music), so it can't be used as a sound."
            }
        }
    }

    /// Converts any audio file AVFoundation can read into a ≤29-second PCM `.caf` in
    /// `Library/Sounds/`, and adds it to the user's sounds.
    static func importTone(from url: URL, kind: ToneKind) throws -> Tone {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let input: AVAudioFile
        do {
            input = try AVAudioFile(forReading: url)
        } catch {
            throw ImportError.unreadable
        }
        let format = input.processingFormat
        let totalFrames = min(input.length, AVAudioFramePosition(format.sampleRate * maxDuration))
        guard totalFrames > 0 else { throw ImportError.unreadable }

        try FileManager.default.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)
        let fileName = "custom_\(UUID().uuidString).caf"
        let outputURL = soundsDirectory.appendingPathComponent(fileName)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        do {
            let output = try AVAudioFile(forWriting: outputURL, settings: settings,
                                         commonFormat: format.commonFormat, interleaved: format.isInterleaved)
            let chunk: AVAudioFrameCount = 32_768
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk) else { throw ImportError.unreadable }
            var remaining = totalFrames
            while remaining > 0 {
                try input.read(into: buffer, frameCount: AVAudioFrameCount(min(AVAudioFramePosition(chunk), remaining)))
                if buffer.frameLength == 0 { break }
                try output.write(from: buffer)
                remaining -= AVAudioFramePosition(buffer.frameLength)
            }
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw ImportError.unreadable
        }

        let record = CustomRecord(
            name: uniqueName(for: url.deletingPathExtension().lastPathComponent),
            fileName: fileName,
            duration: Double(totalFrames) / format.sampleRate
        )
        saveRecords(customRecords(kind) + [record], kind: kind)
        return record.tone
    }

    static func customTones(_ kind: ToneKind) -> [Tone] {
        customRecords(kind)
            .filter { FileManager.default.fileExists(atPath: soundsDirectory.appendingPathComponent($0.fileName).path) }
            .map(\.tone)
    }

    static func rename(_ tone: Tone, to name: String, kind: ToneKind) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        saveRecords(customRecords(kind).map {
            var r = $0
            if r.fileName == tone.id { r.name = String(trimmed.prefix(40)) }
            return r
        }, kind: kind)
    }

    static func delete(_ tone: Tone, kind: ToneKind) {
        guard tone.isCustom else { return }
        try? FileManager.default.removeItem(at: soundsDirectory.appendingPathComponent(tone.id))
        saveRecords(customRecords(kind).filter { $0.fileName != tone.id }, kind: kind)
    }

    // MARK: - Private

    private struct CustomRecord: Codable {
        var name: String
        let fileName: String
        let duration: TimeInterval

        var tone: Tone { Tone(id: fileName, name: name, isCustom: true, duration: duration) }
    }

    private static func defaultsKey(_ kind: ToneKind) -> String { "customTones.\(kind.rawValue)" }

    private static func customRecords(_ kind: ToneKind) -> [CustomRecord] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey(kind)),
              let records = try? JSONDecoder().decode([CustomRecord].self, from: data) else { return [] }
        return records
    }

    private static func saveRecords(_ records: [CustomRecord], kind: ToneKind) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: defaultsKey(kind))
        }
    }

    private static var soundsDirectory: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Sounds")
    }

    private static func builtInFileName(_ name: String) -> String {
        "ft_" + name.lowercased().replacingOccurrences(of: " ", with: "_") + ".caf"
    }

    /// "Song.mp3" → "Song"; "Song (2)" if that name is taken.
    private static func uniqueName(for base: String) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespaces)
        let root = trimmed.isEmpty ? "My sound" : String(trimmed.prefix(40))
        let taken = Set((builtIns(.notification) + builtIns(.ringtone) + customTones(.notification) + customTones(.ringtone)).map(\.name))
        guard taken.contains(root) else { return root }
        var index = 2
        while taken.contains("\(root) (\(index))") { index += 1 }
        return "\(root) (\(index))"
    }

    private static func write(_ notes: [Note], to url: URL) throws {
        let sampleRate = 44_100.0
        let total = notes.reduce(0) { $0 + $1.duration + $1.gap }
        guard total > 0,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate * total)),
              let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = buffer.frameCapacity
        for i in 0..<Int(buffer.frameLength) { channel[i] = 0 }

        var frame = 0
        for note in notes {
            let count = min(Int(sampleRate * note.duration), Int(buffer.frameLength) - frame)
            for i in 0..<max(0, count) {
                let t = Double(i) / sampleRate
                // Short fade in and out so notes don't click.
                let fade = min(1, min(t, note.duration - t) / 0.015)
                channel[frame + i] = Float(sin(2 * .pi * note.frequency * t) * 0.6 * max(0, fade))
            }
            frame += max(0, count) + Int(sampleRate * note.gap)
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let file = try AVAudioFile(forWriting: url, settings: buffer.format.settings)
        try file.write(from: buffer)
    }
}
