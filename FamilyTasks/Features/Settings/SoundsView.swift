import SwiftUI
import UniformTypeIdentifiers

/// Family → Sounds. Choose the notification sound and the urgent ringtone for this phone,
/// add your own from the device, and send a test.
struct SoundsView: View {
    @EnvironmentObject private var router: Router
    @ObservedObject private var settings = SoundSettings.shared
    @State private var testMessage: String?
    @State private var showDenied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel("Sounds").padding(.bottom, 8)
                VStack(spacing: 0) {
                    Button { router.push(.tonePicker(.notification)) } label: {
                        DetailRow(icon: "bell.fill", tint: Theme.brand, title: "Notification sound",
                                  value: ToneLibrary.name(of: settings.notificationToneID))
                    }
                    .buttonStyle(.plain)
                    RowDivider()
                    Button { router.push(.tonePicker(.ringtone)) } label: {
                        DetailRow(icon: "bolt.fill", tint: Theme.urgent, title: "Urgent ringtone",
                                  value: ToneLibrary.name(of: settings.ringtoneID))
                    }
                    .buttonStyle(.plain)
                }
                .card(padding: 0)
                note("Notification sound is for reminders and updates. Urgent ringtone plays for ⚡ Urgent tasks and rings for longer.")

                Toggle(isOn: $settings.vibrate) {
                    HStack(spacing: 12) {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Theme.ink2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text("Vibrate with urgent ring").font(.system(size: 15, weight: .medium))
                    }
                }
                .tint(Theme.done)
                .card(padding: 12)
                .padding(.top, 20)

                SectionLabel("Try it").padding(.top, 24).padding(.bottom, 8)
                HStack(spacing: 8) {
                    testButton("Test reminder", icon: "bell", kind: .notification)
                    testButton("Test urgent", icon: "bolt", kind: .ringtone)
                }
                if let testMessage {
                    Text(testMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.done)
                        .padding(.horizontal, 4)
                        .padding(.top, 10)
                        .transition(.opacity)
                }

                note("Sounds are set for this phone only. Each family member picks their own.")
                    .padding(.top, 14)
            }
            .padding(20)
            .animation(.quick, value: testMessage)
        }
        .background(Theme.background)
        .navigationTitle("Sounds")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .alert("Notifications are off", isPresented: $showDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Turn on notifications for FamilyTasks in Settings to hear reminders.")
        }
    }

    private func testButton(_ title: String, icon: String, kind: ToneKind) -> some View {
        Button {
            Task {
                let sent = await NotificationManager.shared.sendTest(kind, settings: settings)
                if sent {
                    testMessage = "Arriving in 3 seconds. Lock your phone to hear it like a real one."
                    Haptic.success.play()
                } else {
                    showDenied = true
                }
            }
        } label: {
            Label(title, systemImage: icon)
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.ink3)
            .padding(.horizontal, 4)
            .padding(.top, 8)
    }
}

/// Pick a sound: built-in tones, the user's own sounds, and "Add from Files…".
/// Tapping a sound selects it and plays it.
struct TonePickerView: View {
    let kind: ToneKind
    @ObservedObject private var settings = SoundSettings.shared
    @StateObject private var player = TonePreviewPlayer()
    @State private var custom: [Tone] = []
    @State private var showImporter = false
    @State private var importing = false
    @State private var importError: String?
    @State private var renaming: Tone?
    @State private var newName = ""

    private var selectedID: String { settings.selected(kind) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel("Built-in").padding(.bottom, 8)
                toneList(ToneLibrary.builtIns(kind))

                SectionLabel("My sounds").padding(.top, 24).padding(.bottom, 8)
                if !custom.isEmpty {
                    toneList(custom).padding(.bottom, 10)
                }
                addButton

                Text(helpText)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.ink3)
                    .padding(.horizontal, 4)
                    .padding(.top, 10)
            }
            .padding(20)
            .animation(Theme.spring, value: custom.map(\.id))
        }
        .background(Theme.background)
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .onAppear { custom = ToneLibrary.customTones(kind) }
        .onDisappear { player.stop() }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            handleImport(result)
        }
        .alert("Couldn't add sound", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .alert("Rename sound", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Save") {
                if let tone = renaming { ToneLibrary.rename(tone, to: newName, kind: kind) }
                custom = ToneLibrary.customTones(kind)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var helpText: String {
        "Pick any audio file from Files or iCloud Drive (MP3, M4A, WAV…). To use a voice note or a sound from WhatsApp, tap Share → Save to Files first. Sounds longer than 29 seconds are shortened, because iOS doesn't allow longer notification sounds. Songs from Apple Music are copy-protected and can't be used."
    }

    // MARK: - Rows

    private func toneList(_ tones: [Tone]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(tones.enumerated()), id: \.element.id) { index, tone in
                row(tone)
                if index < tones.count - 1 { RowDivider(leading: 54) }
            }
        }
        .card(padding: 0)
    }

    private func row(_ tone: Tone) -> some View {
        let isSelected = selectedID == tone.id
        let isPlaying = player.playingID == tone.id
        return HStack(spacing: 12) {
            Button {
                player.toggle(tone.id)
            } label: {
                Image(systemName: tone.id == ToneLibrary.silentID ? "speaker.slash.fill"
                      : (isPlaying ? "stop.fill" : "play.fill"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isPlaying ? .white : Theme.ink)
                    .frame(width: 30, height: 30)
                    .background(isPlaying ? Theme.brand : Theme.surface2, in: Circle())
                    .bounceEffect(value: isPlaying)
            }
            .buttonStyle(PressableStyle())
            .disabled(tone.id == ToneLibrary.silentID)
            .accessibilityLabel(isPlaying ? "Stop \(tone.name)" : "Play \(tone.name)")

            VStack(alignment: .leading, spacing: 1) {
                Text(tone.name)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if let duration = tone.duration {
                    Text(durationText(duration)).font(.system(size: 12)).foregroundStyle(Theme.ink3)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.brand)
                    .transition(.scale.combined(with: .opacity))
            }
            if tone.isCustom {
                Menu {
                    Button { newName = tone.name; renaming = tone } label: { Label("Rename", systemImage: "pencil") }
                    Button(role: .destructive) { delete(tone) } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("More for \(tone.name)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.quick) { settings.select(tone.id, for: kind) }
            player.play(tone.id)
            Haptic.selection.play()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var addButton: some View {
        Button { showImporter = true } label: {
            HStack(spacing: 10) {
                if importing {
                    ProgressView().tint(Theme.brand)
                } else {
                    Image(systemName: "plus.circle.fill").font(.system(size: 18))
                }
                Text(importing ? "Adding…" : "Add from Files…").font(.system(size: 15, weight: .semibold))
                Spacer()
                Image(systemName: "folder").foregroundStyle(Theme.ink3)
            }
            .foregroundStyle(Theme.brand)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(Theme.brand.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
        }
        .buttonStyle(PressableStyle())
        .disabled(importing)
    }

    // MARK: - Actions

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        importing = true
        // Let the spinner show before the conversion work starts.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            defer { importing = false }
            do {
                let tone = try ToneLibrary.importTone(from: url, kind: kind)
                custom = ToneLibrary.customTones(kind)
                withAnimation(.quick) { settings.select(tone.id, for: kind) }
                player.play(tone.id)
                Haptic.success.play()
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    private func delete(_ tone: Tone) {
        if player.playingID == tone.id { player.stop() }
        ToneLibrary.delete(tone, kind: kind)
        settings.toneDeleted(tone.id)
        custom = ToneLibrary.customTones(kind)
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

#Preview {
    NavigationStack { SoundsView() }.previewEnvironment()
}
