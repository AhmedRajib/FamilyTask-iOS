import SwiftUI
import MapKit

/// 7f · A child finds a place on the map, names it, and sends it to a parent to check.
/// Nothing is shared or usable until a parent or adult approves it.
struct AskPlaceView: View {
    /// The task being made, so parents see why ("for Swimming lesson").
    let forTaskTitle: String?
    /// Called after sending, so the Location page can say "Sent".
    var onSent: (String) -> Void = { _ in }

    @EnvironmentObject private var store: FamilyStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var search = PlaceSearch()
    @State private var query = ""
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
    @State private var hasPin = false
    @State private var foundAddress = ""
    @State private var name = ""
    @State private var emoji = "📍"
    @State private var hint = ""
    @State private var isResolving = false
    @State private var didLoad = false
    @FocusState private var focus: Field?

    private enum Field: Hashable { case search, name, hint }

    private static let suggestions = ["🏊", "⚽", "🏀", "🎹", "📚", "👵", "🏠"]
    private static let radius: Double = 100

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var alreadyAsked: Bool { !trimmedName.isEmpty && store.hasPendingPlaceRequest(named: trimmedName) }
    private var canSend: Bool { hasPin && !trimmedName.isEmpty && !alreadyAsked }

    /// The people who can approve: parents and adults.
    private var approvers: [Member] { store.family.members.filter { $0.role != .child } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel("1 · Find it on the map").padding(.bottom, 8)
                VStack(alignment: .leading, spacing: 8) {
                    searchField
                    if focus == .search && !search.results.isEmpty {
                        results
                    }
                    RadiusMap(region: $region, radius: Self.radius, showsPin: hasPin, pinColor: Theme.urgent,
                              placeholder: "Search above, or tap “Pin here”")
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            if !hasPin {
                                Button("📍 Pin here") { withAnimation(Theme.spring) { hasPin = true } }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.regularMaterial, in: Capsule())
                                    .padding(8)
                            }
                        }
                    Text(hasPin
                         ? [foundAddress, "drag the map to move the pin"].filter { !$0.isEmpty }.joined(separator: " · ")
                         : "Move the map so the middle is the right spot, then tap Pin here.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink3)
                }
                .card(padding: 10)

                SectionLabel("2 · What do you call it?").padding(.top, 20).padding(.bottom, 8)
                TextField("Like “Swimming pool”", text: $name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .focused($focus, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focus = .hint }
                    .card()
                if alreadyAsked {
                    Text("You've already asked for “\(trimmedName)”. Your parents will check it soon.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.highText)
                        .padding(.horizontal, 4)
                        .padding(.top, 6)
                }
                EmojiPicker(selection: $emoji, suggestions: Self.suggestions)
                    .padding(.top, 10)

                SectionLabel("Anything that helps? (optional)").padding(.top, 20).padding(.bottom, 8)
                TextField("Like “The one next to the library”", text: $hint, axis: .vertical)
                    .font(.system(size: 15))
                    .focused($focus, equals: .hint)
                    .card()

                if !approvers.isEmpty {
                    HStack(spacing: 10) {
                        AvatarStack(members: approvers, size: 28, ring: Theme.surface2)
                        Text("\(approvers.map(\.name).formatted(.list(type: .or))) will check it before it's added")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.ink2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.top, 16)
                }
            }
            .padding(20)
            .animation(Theme.spring, value: focus == .search && !search.results.isEmpty)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .navigationTitle("Ask for a place")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button("🙋 Send to parents", action: send)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canSend)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(Theme.background)
        }
        .onAppear(perform: load)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.ink3)
            TextField("Search the name or street", text: $query)
                .font(.system(size: 15))
                .focused($focus, equals: .search)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onChange(of: query) { search.update(query: $0) }
                .onSubmit { if let first = search.results.first { resolve(first) } }
            if search.isSearching || isResolving {
                ProgressView().controlSize(.small)
            } else if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.ink3) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(10)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var results: some View {
        VStack(spacing: 0) {
            ForEach(search.results.prefix(5), id: \.self) { result in
                Button { resolve(result) } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(result.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
                        if !result.subtitle.isEmpty {
                            Text(result.subtitle).font(.system(size: 12)).foregroundStyle(Theme.ink3)
                        }
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                RowDivider(leading: 4)
            }
        }
        .transition(.opacity)
    }

    private func resolve(_ completion: MKLocalSearchCompletion) {
        focus = nil
        isResolving = true
        MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start { response, _ in
            isResolving = false
            guard let item = response?.mapItems.first else {
                Haptic.error.play()
                return
            }
            withAnimation(Theme.spring) {
                region = RadiusMap.region(around: item.placemark.coordinate, radius: Self.radius)
                hasPin = true
            }
            foundAddress = [completion.title, completion.subtitle].filter { !$0.isEmpty }.joined(separator: ", ")
            query = completion.title
        }
    }

    // MARK: - Send

    private func send() {
        let place = Place(name: trimmedName, emoji: emoji, address: foundAddress,
                          latitude: region.center.latitude, longitude: region.center.longitude,
                          radius: Self.radius)
        let sent = store.requestPlace(place, hint: hint.trimmingCharacters(in: .whitespacesAndNewlines),
                                      forTaskTitle: forTaskTitle)
        guard sent else {
            Haptic.error.play()
            return
        }
        Haptic.success.play()
        onSent(trimmedName)
        dismiss()
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let near = store.family.places.first {
            region = RadiusMap.region(around: near.coordinate, radius: 1500)
            search.region = region
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { focus = .search }
    }
}

#Preview {
    NavigationStack { AskPlaceView(forTaskTitle: "Swimming lesson") }.previewEnvironment()
}
