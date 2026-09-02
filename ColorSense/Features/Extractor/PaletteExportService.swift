import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

/// Builds the shareable representations of a palette offered by the Export menu.
/// Everything here is generated on-device — exporting never touches the network.
enum PaletteExportService {
    static func hexList(_ palette: ExtractedPalette) -> String {
        palette.colors.map(\.hex).joined(separator: "\n")
    }

    static func cssVariables(_ palette: ExtractedPalette) -> String {
        let lines = palette.colors.enumerated().map { index, swatch in
            "  --color-\(index + 1): \(swatch.hex); /* \(swatch.name) */"
        }
        return ":root\n{\n" + lines.joined(separator: "\n") + "\n}"
    }

    /// Renders the palette as a shareable card.
    ///
    /// - Parameter includesLogo: draws the ColorSense lockup. Pro users get a clean card;
    ///   everyone else gets the branding. Callers should pass `true` whenever the plan is
    ///   unknown — a Pro user occasionally getting a branded export is a small annoyance, but a
    ///   free user getting clean exports whenever a plan lookup fails gives the feature away.
    @MainActor
    static func uiImage(for palette: ExtractedPalette, includesLogo: Bool = true) -> UIImage? {
        let renderer = ImageRenderer(
            content: ShareCard(palette: palette, includesLogo: includesLogo)
        )
        // The card is already laid out at full pixel size, so it renders 1:1.
        renderer.scale = 1
        return renderer.uiImage
    }

    @MainActor
    static func image(for palette: ExtractedPalette, includesLogo: Bool = true) -> Image? {
        uiImage(for: palette, includesLogo: includesLogo).map(Image.init(uiImage:))
    }

    /// The palette card packaged for `ShareLink`.
    ///
    /// Sharing a SwiftUI `Image` directly does not reliably advertise a photo type to the share
    /// sheet, so "Save to Files" appears but "Save Image" does not. Declaring an explicit PNG
    /// `DataRepresentation` with a filename is what puts the Photos destination back.
    @MainActor
    static func shareable(
        for palette: ExtractedPalette,
        includesLogo: Bool = true
    ) -> SharablePaletteImage? {
        guard
            let uiImage = uiImage(for: palette, includesLogo: includesLogo),
            let data = uiImage.pngData()
        else { return nil }
        return SharablePaletteImage(data: data, preview: Image(uiImage: uiImage))
    }
}

struct SharablePaletteImage: Transferable {
    let data: Data
    /// Only for the share sheet's own thumbnail — the PNG data above is what actually transfers.
    let preview: Image

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
            .suggestedFileName { _ in "ColorSense palette.png" }
    }

    // There is deliberately no save-to-Photos of our own: the system share sheet already offers
    // Save Image alongside AirDrop, Messages and Copy, so a dedicated item duplicated it with
    // strictly fewer capabilities — and dropping it also drops a photo-library add permission
    // the app no longer has to ask for.
}

/// The shareable palette card, ported from the web app's `lib/renderShareCard.ts` so a palette
/// exported from the phone is the same artifact as one exported from the site: same 1080×1350
/// canvas, same ground, padding, radii, type sizes and label treatment.
///
/// Two deliberate departures:
///
/// - **Type is DM Sans, not Inter.** The web canvas uses Inter; DM Sans is the brand UI font
///   (vault section 8) and is already bundled here.
/// - **All swatches render, not the first five.** The web slices to 5 because web palettes are
///   fixed at 5; an iOS palette holds up to 8, and silently dropping three colors from an export
///   would be worse than a slightly taller stack. The bar maths already divides by the count.
private struct ShareCard: View {
    let palette: ExtractedPalette
    let includesLogo: Bool

    // Canvas geometry, all from renderShareCard.ts.
    private let cardWidth: CGFloat = 1080
    private let cardHeight: CGFloat = 1350
    private let padX: CGFloat = 100
    private let padY: CGFloat = 90
    private let gap: CGFloat = 22
    private let barRadius: CGFloat = 28
    private let textInset: CGFloat = 48
    private let lockupReserve: CGFloat = 90

    private var barHeight: CGFloat {
        let count = CGFloat(max(palette.colors.count, 1))
        let areaHeight = cardHeight - padY * 2 - (includesLogo ? lockupReserve : 0)
        return (areaHeight - gap * (count - 1)) / count
    }

    var body: some View {
        ZStack {
            Color(hex: 0xEFF6FB)

            VStack(spacing: 0) {
                VStack(spacing: gap) {
                    ForEach(palette.colors) { swatch in
                        bar(swatch)
                    }
                }
                if includesLogo {
                    lockup
                        .frame(height: lockupReserve)
                }
            }
            .padding(.horizontal, padX)
            .padding(.vertical, padY)
        }
        .frame(width: cardWidth, height: cardHeight)
    }

    private func bar(_ swatch: PaletteColor) -> some View {
        let ink = labelInk(for: swatch)
        return VStack(alignment: .leading, spacing: 6) {
            Text(swatch.name)
                .font(BrandFont.ui(46, weight: .bold))
                .foregroundStyle(ink.name)
            Text("HEX \(swatch.hex.dropFirst().uppercased())")
                .font(BrandFont.ui(24, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(ink.hex)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, textInset)
        .frame(height: barHeight, alignment: .leading)
        .background(swatch.color)
        .clipShape(RoundedRectangle(cornerRadius: barRadius))
    }

    /// Label colors by relative luminance, matching `textColorsFor` in renderShareCard.ts.
    /// The dark tones are deliberately olive rather than neutral grey — that is the web's choice,
    /// kept so the two exports look identical.
    private func labelInk(for swatch: PaletteColor) -> (name: Color, hex: Color) {
        let luminance = ContrastCalculator.relativeLuminance(
            red: swatch.red, green: swatch.green, blue: swatch.blue
        )
        if luminance > 0.75 {
            return (Color(hex: 0x3F4A25), Color(hex: 0x3F4A25, alpha: 0.7))
        }
        if luminance > 0.45 {
            return (Color(hex: 0x1F2A14), Color(hex: 0x1F2A14, alpha: 0.85))
        }
        return (.white.opacity(0.98), .white.opacity(0.78))
    }

    /// Four-square mark plus wordmark. Colors come from `BrandColor` rather than the web's
    /// hardcoded values: the share card there uses #8B5CF6 for the violet, the site logo uses
    /// #6C5CE7, and the vault specifies #7C6DEB. Chris chose the vault value as canonical, so
    /// iOS exports use it and the web is the one that has drifted.
    private var lockup: some View {
        let dot: CGFloat = 20
        let dotGap: CGFloat = 4
        return HStack(spacing: 16) {
            VStack(spacing: dotGap) {
                HStack(spacing: dotGap) {
                    square(BrandColor.coral, dot)
                    square(BrandColor.teal, dot)
                }
                HStack(spacing: dotGap) {
                    square(BrandColor.yellow, dot)
                    square(BrandColor.purple, dot)
                }
            }
            HStack(spacing: 0) {
                Text("Color").foregroundStyle(Color(hex: 0x0F172A))
                Text("Sense").foregroundStyle(BrandColor.purple)
            }
            .font(BrandFont.ui(36, weight: .bold))
        }
        .frame(maxWidth: .infinity)
    }

    private func square(_ color: Color, _ size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 5).fill(color).frame(width: size, height: size)
    }
}
