import SwiftUI
import MapKit

/// Add or edit a family place: name, emoji, where it is, and how close counts as "there".
/// With `requestID`, a parent reviews a child's place request: pre-filled, and saving approves it.
struct PlaceEditorView: View {
    let placeID: UUID?
    var requestID: UUID? = nil
    @EnvironmentObject private var store: FamilyStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "📍"
    @State private var address = ""
    @State private var radius: Double = 150
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
    @State private var hasLocation = false
    @State private var isSearching = false
    @State private var searchFailed = false
    @State private var didLoad = false
    @State private var confirmDelete = false
    @FocusState private var nameFocused: Bool

    private static let suggestions = ["🏠", "🏫", "🛒", "🏥", "👵", "⚽", "🕌"]

    private var existing: Place? { store.place(placeID) }
    private var request: PlaceRequest? { store.placeRequest(requestID) }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let request { requestBanner(request) }
                NameField(placeholder: "Name, like \"Grandma's house\"", text: $name, focused: $nameFocused)

                SectionLabel("Emoji").padding(.top, 20).padding(.bottom, 8)
                EmojiPicker(selection: $emoji, suggestions: Self.suggestions)

                SectionLabel("Where is it?").padding(.top, 20).padding(.bottom, 8)
                VStack(alignment: .leading, spacing: 10) {
                    searchField
                    map
                    HStack {
                        SectionLabel("Radius · \(radiusText)")
                    }
                    Slider(value: $radius, in: 50...1000, step: 10)
                        .tint(Theme.done)
                        .accessibilityValue(radiusText)
                    HStack {
                        Text("50 m"); Spacer(); Text("1 km")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.ink3)
                }
                .card(padding: 10)

                Text("🔒 Places stay on your family's phones.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink3)
                    .padding(.horizontal, 4)
                    .padding(.top, 10)

                if let placeID, let used = usedByText(store.templates(usingPlace: placeID)) {
                    Text(used)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.ink2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.top, 10)
                }

                if existing != nil {
                    EditorDeleteButton(title: "Delete place") { confirmDelete = true }
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .navigationTitle(request != nil ? "Check place" : existing == nil ? "New place" : "Edit place")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            EditorSaveBar(title: request != nil ? "Approve & save" : existing == nil ? "Save place" : "Save",
                          enabled: !trimmedName.isEmpty && hasLocation, action: save)
        }
        .alert("Delete \"\(existing?.name ?? "")\"?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                guard let placeID else { return }
                store.deletePlace(placeID)
                Haptic.success.play()
                dismiss()
            }
        } message: {
            Text(deleteMessage(usedBy: placeID.map(store.templates(usingPlace:)) ?? [], losing: "a place"))
        }
        .onAppear(perform: load)
    }

    /// "Ali asked for this · for Swimming lesson · "The one next to the library""
    private func requestBanner(_ request: PlaceRequest) -> some View {
        let who = store.member(request.memberID)
        return HStack(alignment: .top, spacing: 10) {
            if let who { AvatarView(member: who, size: 30) }
            VStack(alignment: .leading, spacing: 2) {
                Text("**\(who?.name ?? "Someone")** asked for this place\(request.forTaskTitle.map { " for “\($0)”" } ?? "")")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.ink)
                if !request.hint.isEmpty {
                    Text("“\(request.hint)”").font(.system(size: 12.5)).foregroundStyle(Theme.ink2)
                }
                Text("Check the pin and radius, then approve.").font(.system(size: 12)).foregroundStyle(Theme.ink3)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.brandSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.bottom, 14)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.ink3)
            TextField("Search an address or place", text: $address)
                .font(.system(size: 15))
                .submitLabel(.search)
                .onSubmit(search)
            if isSearching { ProgressView().controlSize(.small) }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func search() {
        let query = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearching = true
        searchFailed = false
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if hasLocation { request.region = region }
        MKLocalSearch(request: request).start { response, _ in
            isSearching = false
            guard let item = response?.mapItems.first else {
                searchFailed = true
                Haptic.error.play()
                return
            }
            withAnimation(Theme.spring) {
                region = RadiusMap.region(around: item.placemark.coordinate, radius: radius)
                hasLocation = true
            }
            if let title = item.name, !title.isEmpty { address = title }
            if trimmedName.isEmpty, let title = item.name { name = title }
        }
    }

    // MARK: - Map

    /// The pin stays in the middle; drag the map to move it. The ring shows the radius.
    private var map: some View {
        RadiusMap(region: $region, radius: radius, showsPin: hasLocation,
                  placeholder: searchFailed ? "Couldn't find that. Try a fuller address." : "Search above to drop the pin")
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityLabel(hasLocation ? "Map. Drag to move the pin." : "Map. Search an address to place the pin.")
    }

    private var radiusText: String { FamilyTasks.radiusText(radius) }

    // MARK: - Load & save

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let request {
            let place = request.place
            name = place.name
            emoji = place.emoji
            address = place.address
            radius = place.radius
            region = RadiusMap.region(around: place.coordinate, radius: place.radius)
            hasLocation = true
        } else if let existing {
            name = existing.name
            emoji = existing.emoji
            address = existing.address
            radius = existing.radius
            region = RadiusMap.region(around: existing.coordinate, radius: existing.radius)
            hasLocation = true
        } else {
            // Start the map near the family's other places.
            if let near = store.family.places.first {
                region.center = CLLocationCoordinate2D(latitude: near.latitude, longitude: near.longitude)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { nameFocused = true }
        }
    }

    private func save() {
        var item = existing ?? Place(name: "", emoji: "", address: "", latitude: 0, longitude: 0, radius: 150)
        item.name = trimmedName
        item.emoji = emoji
        item.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        item.latitude = region.center.latitude
        item.longitude = region.center.longitude
        item.radius = radius
        if let requestID {
            store.approvePlaceRequest(requestID, as: item)
        } else {
            store.savePlace(item)
        }
        Haptic.success.play()
        dismiss()
    }
}

#Preview {
    NavigationStack { PlaceEditorView(placeID: nil) }.previewEnvironment()
}
