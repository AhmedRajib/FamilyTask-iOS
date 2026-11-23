import SwiftUI
import MapKit
import Combine

/// "Location" on New Task: a saved family place, or somewhere new just for this task.
/// Parents & adults: search (7b), then the chosen place on a map (7c).
/// Children: family places only, plus "Somewhere else?" to ask a parent (7e–7h).
struct LocationPickerView: View {
    @Binding var location: LocationReminder?
    /// The task being made, passed on to place requests ("for Swimming lesson").
    var taskTitle: String = ""
    @EnvironmentObject private var store: FamilyStore
    @Environment(\.dismiss) private var dismiss

    private enum Choice: Equatable {
        case family(UUID)
        case custom(Place)
    }

    @StateObject private var search = PlaceSearch()
    @State private var query = ""
    @State private var choice: Choice?
    @State private var trigger: PlaceTrigger = .arriving
    @State private var customRadius: Double = 100
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
    @State private var saveToFamily = false
    @State private var isResolving = false
    @State private var didLoad = false
    @FocusState private var searchFocused: Bool
    @State private var showAsk = false
    @State private var sentName: String?

    private var isKid: Bool { !store.permissions.canManageShortcuts }

    var body: some View {
        Group {
            if isKid { kidStep } else if choice == nil { searchStep } else { chosenStep }
        }
        .navigationDestination(isPresented: $showAsk) {
            AskPlaceView(forTaskTitle: taskTitle) { name in
                withAnimation(Theme.spring) { sentName = name }
            }
        }
        .background(Theme.background)
        .navigationTitle("Location")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            if location != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Remove", role: .destructive) {
                        location = nil
                        dismiss()
                    }
                    .foregroundStyle(Theme.urgent)
                }
            }
        }
        .animation(Theme.spring, value: choice == nil)
        .onAppear(perform: load)
    }

    // MARK: - Kids: family places + ask a parent (7e, 7h)

    private var kidStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let sentName {
                    Label("Sent! Your parents will check “\(sentName)”. You can save the task now and add the place later.",
                          systemImage: "paperplane.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.done)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.doneSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.bottom, 14)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                SectionLabel("Where?").padding(.bottom, 8)
                if store.family.places.isEmpty {
                    Text("Your family hasn't saved any places yet.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.ink3)
                        .padding(.horizontal, 4)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                        ForEach(store.family.places) { placeTile($0) }
                    }
                }

                Button { showAsk = true } label: {
                    HStack(spacing: 12) {
                        Text("🙋")
                            .font(.system(size: 18))
                            .frame(width: 36, height: 36)
                            .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Somewhere else?").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.brand)
                            Text("Find it on the map and ask a parent").font(.system(size: 12)).foregroundStyle(Theme.ink2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.brand)
                    }
                    .padding(12)
                    .background(Theme.brandSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.brand, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 14)

                ForEach(store.myPlaceRequests.filter { $0.status == .pending }) { request in
                    HStack(spacing: 8) {
                        Text("⏳")
                        (Text("Still waiting: ") + Text("\(request.place.emoji) \(request.place.name)").bold()
                         + Text(" · asked \(request.date.formatted(.relative(presentation: .named)))"))
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.highText)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(Theme.highSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 10)
                }

                SectionLabel("Remind me when").padding(.top, 20).padding(.bottom, 8)
                HStack(spacing: 8) {
                    triggerOption(.arriving, hint: "When I get there")
                    triggerOption(.leaving, hint: "When I head off")
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(kidButtonTitle, action: use)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(choice == nil)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(Theme.background)
        }
    }

    private var kidButtonTitle: String {
        if case .family(let id) = choice, let place = store.place(id) { return "Use \(place.name)" }
        return "Pick a place"
    }

    private func placeTile(_ place: Place) -> some View {
        let isOn = choice == .family(place.id)
        return Button { choice = .family(place.id) } label: {
            HStack(spacing: 10) {
                Text(place.emoji).font(.system(size: 22))
                Text(place.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(minHeight: 56)
            .background(isOn ? Theme.surface2 : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isOn ? Theme.ink : Theme.line, lineWidth: 1.5))
        }
        .buttonStyle(PressableStyle())
        .haptic(.selection, trigger: isOn)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - Step 1: search (7b)

    private var searchStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                searchField

                if !store.family.places.isEmpty {
                    SectionLabel("Family places").padding(.top, 18).padding(.bottom, 8)
                    familyChips(selected: nil)
                }

                SectionLabel(query.isEmpty ? "Somewhere new" : "Search results")
                    .padding(.top, 18).padding(.bottom, 8)
                VStack(spacing: 0) {
                    ForEach(search.results, id: \.self) { result in
                        Button { resolve(result) } label: {
                            resultRow(icon: "mappin", tint: Theme.urgent, soft: Theme.urgentSoft,
                                      title: result.title, subtitle: result.subtitle)
                        }
                        .buttonStyle(.plain)
                        RowDivider(leading: 58)
                    }
                    if !query.isEmpty && search.results.isEmpty && !search.isSearching {
                        Text("No matches yet. Try a street, town or business name.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.ink3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                        RowDivider(leading: 14)
                    }
                    Button(action: dropPin) {
                        resultRow(icon: "mappin.and.ellipse", tint: Theme.brand, soft: Theme.brandSoft,
                                  title: "Drop a pin on the map", subtitle: "For places without an address")
                    }
                    .buttonStyle(.plain)
                }
                .card(padding: 0)
                .overlay { if isResolving { ProgressView() } }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.ink3)
            TextField("Search an address or place", text: $query)
                .font(.system(size: 15))
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onChange(of: query) { search.update(query: $0) }
                .onSubmit { if let first = search.results.first { resolve(first) } }
            if search.isSearching {
                ProgressView().controlSize(.small)
            } else if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.ink3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line))
    }

    private func resultRow(icon: String, tint: Color, soft: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(soft, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.ink3).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Step 2: chosen (7c)

    private var chosenStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                RadiusMap(region: $region, radius: activeRadius,
                          isInteractive: isCustom, pinColor: isCustom ? Theme.urgent : Theme.ink)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        Button { withAnimation(Theme.spring) { choice = nil } } label: {
                            Label("Search again", systemImage: "magnifyingglass")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.regularMaterial, in: Capsule())
                        }
                        .padding(10)
                    }
                    .accessibilityLabel(isCustom ? "Map. Drag to move the pin." : "Map")

                if isCustom {
                    Text("Drag the map to fine-tune the pin.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink3)
                        .padding(.horizontal, 4)
                        .padding(.top, 6)
                }

                SectionLabel("Place").padding(.top, 18).padding(.bottom, 8)
                familyChips(selected: choice)

                SectionLabel("Remind when").padding(.top, 18).padding(.bottom, 8)
                HStack(spacing: 8) {
                    triggerOption(.arriving, hint: "When you get there")
                    triggerOption(.leaving, hint: "When you head off")
                }

                SectionLabel("Radius · \(radiusText(activeRadius))").padding(.top, 18).padding(.bottom, 8)
                if isCustom {
                    VStack(spacing: 4) {
                        Slider(value: $customRadius, in: 50...1000, step: 10)
                            .tint(Theme.done)
                            .accessibilityValue(radiusText(customRadius))
                        HStack { Text("50 m"); Spacer(); Text("1 km") }
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.ink3)
                    }
                    .card(padding: 12)

                    if store.permissions.canManageShortcuts {
                        Toggle(isOn: $saveToFamily) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Also save to family places").font(.system(size: 15, weight: .medium))
                                Text("So everyone can pick it next time").font(.system(size: 12)).foregroundStyle(Theme.ink3)
                            }
                        }
                        .tint(Theme.done)
                        .card(padding: 12)
                        .padding(.top, 12)
                    }
                } else {
                    Text("Set for the whole family in Shortcuts.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink3)
                        .padding(.horizontal, 4)
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button("Use this location", action: use)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(Theme.background)
        }
    }

    private func triggerOption(_ value: PlaceTrigger, hint: String) -> some View {
        let isOn = trigger == value
        return Button { trigger = value } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(value.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(hint).font(.system(size: 11.5)).foregroundStyle(Theme.ink3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(isOn ? Theme.surface2 : Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isOn ? Theme.ink : Theme.line, lineWidth: 1.5))
        }
        .buttonStyle(PressableStyle())
        .haptic(.selection, trigger: isOn)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - Family chips (both steps)

    private func familyChips(selected: Choice?) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if case .custom(let place) = selected {
                    chip("📍 \(place.name)", isOn: true, custom: true) {}
                }
                ForEach(store.family.places) { place in
                    chip("\(place.emoji) \(place.name)", isOn: selected == .family(place.id), custom: false) {
                        pickFamily(place)
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func chip(_ label: String, isOn: Bool, custom: Bool, action: @escaping () -> Void) -> some View {
        let onColor = custom ? Theme.brand : Theme.ink
        return Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(isOn ? .white : (custom ? Theme.brand : Theme.ink))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isOn ? onColor : (custom ? Theme.brandSoft : Theme.surface), in: Capsule())
                .overlay(Capsule().strokeBorder(isOn ? onColor : Theme.line))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - Actions

    private var isCustom: Bool { if case .custom = choice { true } else { false } }

    private var activeRadius: Double {
        switch choice {
        case .family(let id): store.place(id)?.radius ?? 150
        case .custom, nil: customRadius
        }
    }

    private func pickFamily(_ place: Place) {
        searchFocused = false
        withAnimation(Theme.spring) {
            choice = .family(place.id)
            region = RadiusMap.region(around: place.coordinate, radius: place.radius)
        }
    }

    private func resolve(_ completion: MKLocalSearchCompletion) {
        searchFocused = false
        isResolving = true
        MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start { response, _ in
            isResolving = false
            guard let item = response?.mapItems.first else {
                Haptic.error.play()
                return
            }
            let address = completion.subtitle.isEmpty ? (item.placemark.title ?? "") : completion.subtitle
            setCustom(Place(name: item.name ?? completion.title, emoji: "📍", address: address,
                            latitude: item.placemark.coordinate.latitude,
                            longitude: item.placemark.coordinate.longitude, radius: customRadius))
        }
    }

    private func dropPin() {
        searchFocused = false
        setCustom(Place(name: "Dropped pin", emoji: "📍", address: "",
                        latitude: region.center.latitude, longitude: region.center.longitude, radius: customRadius))
    }

    private func setCustom(_ place: Place) {
        withAnimation(Theme.spring) {
            choice = .custom(place)
            region = RadiusMap.region(around: place.coordinate, radius: place.radius)
        }
    }

    private func use() {
        switch choice {
        case .family(let id):
            location = LocationReminder(placeID: id, trigger: trigger)
        case .custom(var place):
            // The pin is wherever the map's centre ended up.
            place.latitude = region.center.latitude
            place.longitude = region.center.longitude
            place.radius = customRadius
            if saveToFamily && store.permissions.canManageShortcuts {
                store.savePlace(place)
                location = LocationReminder(placeID: place.id, trigger: trigger)
            } else {
                location = LocationReminder(custom: place, trigger: trigger)
            }
        case nil:
            return
        }
        Haptic.success.play()
        dismiss()
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        // Search and the map start near the family's places.
        if let near = store.family.places.first {
            region = RadiusMap.region(around: near.coordinate, radius: 1500)
            search.region = region
        }
        guard let location else {
            if isKid {
                // 7h: a place a parent just approved for me is ready to use.
                if let approved = store.myPlaceRequests.first(where: { $0.status == .approved }),
                   let id = approved.approvedPlaceID, store.place(id) != nil {
                    choice = .family(id)
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { searchFocused = true }
            }
            return
        }
        trigger = location.trigger
        if let custom = location.custom {
            customRadius = custom.radius
            setCustom(custom)
        } else if let place = store.place(location.placeID) {
            pickFamily(place)
        }
    }
}

// MARK: - Search as you type

/// Wraps MKLocalSearchCompleter: addresses and businesses as you type.
final class PlaceSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published private(set) var results: [MKLocalSearchCompletion] = []
    @Published private(set) var isSearching = false

    private let completer = MKLocalSearchCompleter()

    var region: MKCoordinateRegion {
        get { completer.region }
        set { completer.region = newValue }
    }

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completer.cancel()
            results = []
            isSearching = false
            return
        }
        isSearching = true
        completer.queryFragment = trimmed
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = Array(completer.results.prefix(8))
        isSearching = false
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
        isSearching = false
    }
}

#Preview {
    NavigationStack { LocationPickerView(location: .constant(nil)) }.previewEnvironment()
}
