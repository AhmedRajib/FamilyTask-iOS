import SwiftUI
import MapKit

/// A map with a pin fixed in the centre and a dashed ring showing the radius.
/// Drag the map to move the pin (when `isInteractive`).
struct RadiusMap: View {
    @Binding var region: MKCoordinateRegion
    let radius: Double
    var showsPin = true
    var isInteractive = true
    var pinColor: Color = Theme.ink
    var placeholder: String? = nil

    var body: some View {
        GeometryReader { geo in
            let metersPerPoint = region.span.latitudeDelta * 111_000 / max(geo.size.height, 1)
            let diameter = min(CGFloat(radius * 2 / max(metersPerPoint, 0.0001)), geo.size.width * 2)
            ZStack {
                Map(coordinateRegion: $region, interactionModes: isInteractive ? .all : [])
                if showsPin {
                    Circle()
                        .fill(Theme.done.opacity(0.16))
                        .overlay(Circle().strokeBorder(Theme.done, style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
                        .frame(width: diameter, height: diameter)
                        .allowsHitTesting(false)
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white, pinColor)
                        .offset(y: -15)
                        .allowsHitTesting(false)
                } else if let placeholder {
                    Text(placeholder)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .allowsHitTesting(false)
                }
            }
        }
    }

    /// A region that comfortably shows `radius` around `center`.
    static func region(around center: CLLocationCoordinate2D, radius: Double) -> MKCoordinateRegion {
        MKCoordinateRegion(center: center,
                           latitudinalMeters: max(radius * 5, 600),
                           longitudinalMeters: max(radius * 5, 600))
    }
}

extension Place {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

func radiusText(_ radius: Double) -> String {
    radius >= 1000 ? String(format: "%.1f km", radius / 1000) : "\(Int(radius)) m"
}
