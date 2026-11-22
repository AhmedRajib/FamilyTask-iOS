import SwiftUI

/// Family shortcuts: quick tasks, places and times, saved once and reused by everyone.
struct ShortcutsView: View {
    @EnvironmentObject private var store: FamilyStore
    @EnvironmentObject private var router: Router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Save it once, and everyone in the family can reuse it in one tap.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink2)
                    .padding(.horizontal, 4)

                SectionLabel("⚡ Quick tasks").padding(.top, 20).padding(.bottom, 8)
                VStack(spacing: 0) {
                    ForEach(Array(store.family.templates.enumerated()), id: \.element.id) { index, template in
                        Button { router.push(.newTask(templateID: template.id)) } label: {
                            row(emoji: template.emoji, title: template.title, detail: detail(for: template))
                        }
                        .buttonStyle(.plain)
                        if index < store.family.templates.count - 1 { RowDivider(leading: 58) }
                    }
                }
                .card(padding: 0)

                SectionLabel("📍 Places").padding(.top, 20).padding(.bottom, 8)
                VStack(spacing: 0) {
                    ForEach(Array(store.family.places.enumerated()), id: \.element.id) { index, place in
                        row(emoji: place.emoji, title: place.name,
                            detail: "\(place.address) · \(place.radiusText)", chevron: false)
                        if index < store.family.places.count - 1 { RowDivider(leading: 58) }
                    }
                }
                .card(padding: 0)

                SectionLabel("🕐 Times").padding(.top, 20).padding(.bottom, 8)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                    ForEach(store.family.times) { time in
                        HStack(spacing: 10) {
                            Text(time.emoji).font(.system(size: 20))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(time.name).font(.system(size: 14, weight: .semibold))
                                Text(time.timeText).font(.system(size: 12)).foregroundStyle(Theme.ink2)
                            }
                            Spacer(minLength: 0)
                        }
                        .card(padding: 12)
                    }
                }

                Text("Adding and editing shortcuts is coming next.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink3)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            }
            .padding(20)
        }
        .background(Theme.background)
        .navigationTitle("Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    private func detail(for template: TaskTemplate) -> String {
        var parts: [String] = []
        if let place = store.place(template.placeID) { parts.append(place.name) }
        if let time = store.time(template.timeShortcutID) { parts.append(time.timeText) }
        if template.repeatRule != .never { parts.append(template.repeatRule.title) }
        parts.append(template.priority.title)
        return parts.joined(separator: " · ")
    }

    private func row(emoji: String, title: String, detail: String, chevron: Bool = true) -> some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 17))
                .frame(width: 32, height: 32)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(detail).font(.system(size: 12)).foregroundStyle(Theme.ink3).lineLimit(1)
            }
            Spacer()
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack { ShortcutsView() }.previewEnvironment()
}
