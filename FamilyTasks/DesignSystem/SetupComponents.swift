import SwiftUI
import CoreImage.CIFilterBuiltins
import VisionKit
import Vision

// MARK: - Colour picker

struct ColorChoiceRow: View {
    @Binding var selection: UInt32

    var body: some View {
        HStack {
            ForEach(Member.palette, id: \.self) { hex in
                let isOn = hex == selection
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { selection = hex }
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 32, height: 32)
                        .padding(4)
                        .overlay(Circle().strokeBorder(isOn ? Theme.ink : .clear, lineWidth: 2))
                        .scaleEffect(isOn ? 1.05 : 1)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Colour \(Member.palette.firstIndex(of: hex).map { $0 + 1 } ?? 0)")
                .accessibilityAddTraits(isOn ? .isSelected : [])
                if hex != Member.palette.last { Spacer(minLength: 0) }
            }
        }
        .haptic(.selection, trigger: selection)
        .card(padding: 10)
    }
}

// MARK: - Role cards

struct RoleCards: View {
    @Binding var selection: Role
    var showsBlurb = true
    var isAllowed: (Role) -> Bool = { _ in true }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Role.allCases, id: \.self) { role in
                let isOn = role == selection
                let allowed = isAllowed(role)
                Button {
                    withAnimation(.quick(0.25)) { selection = role }
                } label: {
                    VStack(spacing: 3) {
                        Text("\(role.emoji) \(role.title)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        if showsBlurb {
                            Text(role.blurb)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.ink3)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: showsBlurb ? 64 : 44)
                    .padding(.horizontal, 6)
                    .background(isOn ? Theme.surface2 : Theme.surface,
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(isOn ? Theme.ink : Theme.line, lineWidth: isOn ? 2 : 1.5))
                }
                .buttonStyle(PressableStyle())
                .disabled(!allowed)
                .opacity(allowed ? 1 : 0.4)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .haptic(.selection, trigger: selection)
    }
}

// MARK: - Big avatar preview

struct AvatarPreview: View {
    let name: String
    let colorHex: UInt32

    var body: some View {
        Text(name.trimmingCharacters(in: .whitespaces).prefix(1).uppercased().ifEmpty("?"))
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 76, height: 76)
            .background(Color(hex: colorHex), in: Circle())
            .contentTransition(.numericText())
            .animation(Theme.spring, value: colorHex)
            .animation(Theme.spring, value: name.prefix(1))
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}

// MARK: - QR code

struct QRCodeView: View {
    let text: String

    var body: some View {
        if let image = Self.render(text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .accessibilityLabel("QR code for the invite")
        } else {
            Color.clear
        }
    }

    static func render(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// What the invite QR code contains. Scanning anything else is ignored.
enum InvitePayload {
    static let prefix = "FAMILYTASKS-INVITE:"

    static func encode(_ code: String) -> String { prefix + code }

    static func decode(_ payload: String) -> String? {
        guard payload.hasPrefix(prefix) else { return nil }
        return String(payload.dropFirst(prefix.count))
    }
}

// MARK: - QR scanner (VisionKit)

struct CodeScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item,
                   let payload = barcode.payloadStringValue,
                   let code = InvitePayload.decode(payload) {
                    onCode(code)
                    return
                }
            }
        }
    }
}

// MARK: - Shake (wrong code)

struct Shake: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 4), y: 0))
    }
}

// MARK: - Setup page title

struct SetupTitle: View {
    let title: String
    let subtitle: String
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 8) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink2)
        }
        .multilineTextAlignment(alignment == .center ? .center : .leading)
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }
}
