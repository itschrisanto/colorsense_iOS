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
}

extension Color {
    /// Resolves to sRGB components in the 0...1 range for contrast math.
    func resolveRGBA() -> (red: Double, green: Double, blue: Double) {
        let resolved = self.resolve(in: EnvironmentValues())
        return (Double(resolved.red), Double(resolved.green), Double(resolved.blue))
    }
}
