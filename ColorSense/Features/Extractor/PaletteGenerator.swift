import Foundation

/// Produces the next palette when the user taps Generate. Ported from the web app's
/// `relatedPalette()` in labColor.ts, together with the Shuffle wiring in LabContext.tsx, so the
/// same photo drifts the same way on both platforms.
///
/// The palette stays *anchored* rather than drifting compoundingly: every iteration derives from
/// the anchor colors (the locked swatches if the user has locked any, otherwise the original
/// extract), and `iteration` selects which hue scheme to apply. That is what stops a long run
/// from wandering into mud.
///
/// Iterations 0-9 cycle three tight schemes — monochromatic, analogous, complementary. From
/// iteration 10 the pool "widens" to include triadic, split-complementary and broad schemes,
/// with larger jitter. It never dead-ends and never goes fully random, which is why the UI shows
/// no countdown: the tenth tap is a change in character, not a limit.
enum PaletteGenerator {
    /// Iteration at which the scheme pool widens. Matches `widen = iteration >= 10` on the web.
    static let wideningIteration = 10

    /// Hue offsets in degrees per swatch, relative to an anchor color's hue.
    private static let tightSchemes: [[Double]] = [
        [0, 0, 0, 0, 0, 0, 0, 0],              // monochromatic — vary lightness/saturation only
        [-30, -15, 0, 15, 30, -45, 45, 0],     // analogous
        [0, 180, 0, 180, 30, 150, 210, 0],     // complementary mix
    ]
    private static let wideSchemes: [[Double]] = [
        [0, 120, 240, 60, 300, 180, 30, 210],  // triadic-ish
        [0, 150, 210, 30, 330, 90, 270, 180],  // split complementary
        [0, 45, 90, 200, 250, 135, 315, 25],   // broad but still anchored
    ]

    /// - Parameters:
    ///   - anchors: colors to stay relevant to. Callers pass the locked swatches when there are
    ///     any, otherwise the original extract.
    ///   - count: how many swatches to produce.
    ///   - iteration: how many times Generate has been tapped for this extract.
    static func colors(anchoredTo anchors: [PaletteColor], count: Int, iteration: Int) -> [PaletteColor] {
        let seeds = anchors.isEmpty
            ? [PaletteColor(hex: 0x888888, dominance: 0)]
            : anchors
        let hsls = seeds.map { ColorMath.hsl(fromRed: $0.red, green: $0.green, blue: $0.blue) }

        let widen = iteration >= wideningIteration
        let pool = widen ? tightSchemes + wideSchemes : tightSchemes
        let scheme = pool[iteration % pool.count]

        return (0..<count).map { index in
            let anchor = hsls[index % hsls.count]
            let offset = scheme[index % scheme.count]

            let hueJitter = Double.random(in: -0.5...0.5) * (widen ? 40 : 14)
            let hue = anchor.hue + offset + hueJitter

            // Revive near-greys, or the whole output comes back dull.
            var saturation = anchor.saturation < 0.08 ? 0.5 : anchor.saturation
            saturation = (saturation + Double.random(in: -0.5...0.5) * (widen ? 0.3 : 0.15))
                .clamped(to: 0.25...0.95)

            let lightness = (anchor.lightness + Double.random(in: -0.5...0.5) * (widen ? 0.3 : 0.16))
                .clamped(to: 0.18...0.9)

            let rgb = ColorMath.rgb(from: .init(hue: hue, saturation: saturation, lightness: lightness))
            return PaletteColor(
                red: rgb.red,
                green: rgb.green,
                blue: rgb.blue,
                dominance: anchors.indices.contains(index) ? anchors[index].dominance : 0
            )
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
