import SwiftUI
import Observation

@Observable
final class WCAGCheckerViewModel {
    var foreground: Color
    var background: Color
    /// The app's current palette, offered as tappable shortcuts under each picker so the checker
    /// works on the same colors as every other tool rather than starting from black on white.
    let paletteColors: [PaletteColor]

    /// Seeds the background from the palette's most dominant color and the text color from
    /// whichever remaining swatch contrasts with it best — so the checker opens on the most
    /// usable pairing in the palette instead of an arbitrary one.
    init(palette: ExtractedPalette = .sample) {
        paletteColors = palette.colors

        guard let dominant = palette.colors.first else {
            foreground = .black
            background = .white
            return
        }
        background = dominant.color

        let bestContrasting = palette.colors.dropFirst().max { lhs, rhs in
            ContrastCalculator.ratio(
                r1: lhs.red, g1: lhs.green, b1: lhs.blue,
                r2: dominant.red, g2: dominant.green, b2: dominant.blue
            ) < ContrastCalculator.ratio(
                r1: rhs.red, g1: rhs.green, b1: rhs.blue,
                r2: dominant.red, g2: dominant.green, b2: dominant.blue
            )
        }
        foreground = bestContrasting?.color
            ?? (ContrastCalculator.prefersLightText(
                onRed: dominant.red, green: dominant.green, blue: dominant.blue
            ) ? .white : .black)
    }

    var ratio: Double {
        let fg = foreground.resolveRGBA()
        let bg = background.resolveRGBA()
        return ContrastCalculator.ratio(
            r1: fg.red, g1: fg.green, b1: fg.blue,
            r2: bg.red, g2: bg.green, b2: bg.blue
        )
    }

    var normalTextLevel: ContrastCalculator.Level { ContrastCalculator.normalTextLevel(for: ratio) }
    var largeTextLevel: ContrastCalculator.Level { ContrastCalculator.largeTextLevel(for: ratio) }

    /// The same plain-language grade the colour detail card shows, so one pairing doesn't get
    /// described two different ways in two places.
    var rating: ContrastCalculator.Rating { ContrastCalculator.rating(for: ratio) }

    /// All four WCAG checks plus the best grade, matching the web app's WCAG panel.
    var verdict: ContrastCalculator.Verdict { ContrastCalculator.verdict(for: ratio) }

    /// The nudge behind "Fix it": moves the *text* colour, never the background.
    ///
    /// Backgrounds are usually the fixed thing in a real design — a brand surface, a page — and
    /// the text on them is what a designer has licence to adjust. Returns nil when no lightness
    /// of this hue can clear the target against that background, which is a real answer worth
    /// showing rather than a silent no-op.
    func suggestedFix(target: Double = 4.5) -> (swatch: PaletteColor, ratio: Double, wentLighter: Bool)? {
        let fg = foreground.resolveRGBA()
        let bg = background.resolveRGBA()
        return ContrastCalculator.suggestFix(
            adjust: PaletteColor(red: fg.red, green: fg.green, blue: fg.blue, dominance: 0),
            anchor: PaletteColor(red: bg.red, green: bg.green, blue: bg.blue, dominance: 0),
            target: target
        )
    }

    func apply(_ fix: (swatch: PaletteColor, ratio: Double, wentLighter: Bool)) {
        foreground = fix.swatch.color
    }

    func swap() {
        let previousForeground = foreground
        foreground = background
        background = previousForeground
    }

    enum Role { case text, background }

    /// Which role, if any, a palette swatch currently fills. Compared by hex rather than by
    /// identity so a colour chosen through the system picker still lights up its matching
    /// swatch — and so a swatch stops being marked as soon as the picker moves off it.
    ///
    /// Deliberately does not build a `PaletteColor` to read `.hex`: that would run the
    /// 1,566-entry name lookup once per swatch on every redraw.
    func role(of swatch: PaletteColor) -> Role? {
        if Self.hexString(of: foreground) == swatch.hex { return .text }
        if Self.hexString(of: background) == swatch.hex { return .background }
        return nil
    }

    func assign(_ swatch: PaletteColor, to role: Role) {
        switch role {
        case .text: foreground = swatch.color
        case .background: background = swatch.color
        }
    }

    private static func hexString(of color: Color) -> String {
        let rgb = color.resolveRGBA()
        return String(
            format: "#%02X%02X%02X",
            Int((rgb.red * 255).rounded()),
            Int((rgb.green * 255).rounded()),
            Int((rgb.blue * 255).rounded())
        )
    }
}

extension Color {
    /// Resolves to sRGB components in the 0...1 range for contrast math.
    func resolveRGBA() -> (red: Double, green: Double, blue: Double) {
        let resolved = self.resolve(in: EnvironmentValues())
        return (Double(resolved.red), Double(resolved.green), Double(resolved.blue))
    }
}
