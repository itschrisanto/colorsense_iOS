import Foundation

/// Colour-vision simulation, ported from the web app's `lib/colorBlind.ts`.
///
/// Uses the Machado et al. (2009) model at severity 1.0 — full dichromacy. The matrices are
/// defined in *linear* sRGB, so channels are linearised before the transform and re-encoded
/// after; applying them to gamma-encoded values would give plausible-looking but wrong colours.
enum ColorBlindness {
    enum Kind: String, CaseIterable, Identifiable {
        case deuteranopia, protanopia, tritanopia

        var id: String { rawValue }

        var label: String {
            switch self {
            case .deuteranopia: return "Deuteranopia"
            case .protanopia: return "Protanopia"
            case .tritanopia: return "Tritanopia"
            }
        }

        var prevalence: String {
            switch self {
            case .deuteranopia: return "~6% of men"
            case .protanopia: return "~2% of men"
            case .tritanopia: return "rare"
            }
        }

        /// Machado et al. (2009), severity 1.0.
        var matrix: [[Double]] {
            switch self {
            case .deuteranopia:
                return [[0.367322, 0.860646, -0.227968],
                        [0.280085, 0.672501, 0.047413],
                        [-0.01182, 0.04294, 0.968881]]
            case .protanopia:
                return [[0.152286, 1.052583, -0.204868],
                        [0.114503, 0.786281, 0.099216],
                        [-0.003882, -0.048116, 1.051998]]
            case .tritanopia:
                return [[1.255528, -0.076749, -0.178779],
                        [-0.078411, 0.930809, 0.147602],
                        [0.004733, 0.691367, 0.3039]]
            }
        }
    }

    struct ConfusablePair: Equatable {
        let first: Int
        let second: Int
        let deltaE: Double
    }

    /// How one colour appears to someone with the given colour vision.
    static func simulate(_ swatch: PaletteColor, as kind: Kind) -> PaletteColor {
        let r = linear(swatch.red)
        let g = linear(swatch.green)
        let b = linear(swatch.blue)
        let m = kind.matrix
        return PaletteColor(
            red: encode(m[0][0] * r + m[0][1] * g + m[0][2] * b),
            green: encode(m[1][0] * r + m[1][1] * g + m[1][2] * b),
            blue: encode(m[2][0] * r + m[2][1] * g + m[2][2] * b),
            dominance: swatch.dominance
        )
    }

    static func simulate(_ colors: [PaletteColor], as kind: Kind) -> [PaletteColor] {
        colors.map { simulate($0, as: kind) }
    }

    /// Pairs that collapse to nearly the same tone once simulated, sorted closest first.
    ///
    /// The default threshold of 14 is the web's: below it, two colours are "easily confused". It
    /// matters when a palette uses colour alone to signal meaning — success against error — since
    /// those viewers cannot tell the two apart.
    static func confusablePairs(
        _ colors: [PaletteColor],
        as kind: Kind,
        threshold: Double = 14
    ) -> [ConfusablePair] {
        let labs = simulate(colors, as: kind).map(preciseLab)
        var pairs: [ConfusablePair] = []
        for i in labs.indices {
            for j in labs.indices where j > i {
                let distance = deltaE(labs[i], labs[j])
                if distance < threshold {
                    pairs.append(ConfusablePair(first: i, second: j, deltaE: distance))
                }
            }
        }
        return pairs.sorted { $0.deltaE < $1.deltaE }
    }

    // MARK: - Maths

    private static func linear(_ channel: Double) -> Double {
        channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }

    /// Back to gamma-encoded sRGB, clamped and quantised to 8 bits exactly as the web does — the
    /// rounding is what makes a simulated hex match across the two products.
    private static func encode(_ channel: Double) -> Double {
        let v = channel <= 0.0031308 ? channel * 12.92 : 1.055 * pow(channel, 1 / 2.4) - 0.055
        return (min(1, max(0, v)) * 255).rounded() / 255
    }

    /// Unrounded LAB, deliberately not `ColorMath.lab`.
    ///
    /// That one returns `Int`s because it feeds the detail card, where LAB is displayed. ΔE here
    /// is compared against a threshold of 14, and rounding each component to a whole number first
    /// would flip pairs sitting near that boundary. Same formulas, different precision, for a
    /// different job.
    private static func preciseLab(_ swatch: PaletteColor) -> (Double, Double, Double) {
        func f(_ channel: Double) -> Double {
            (channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)) * 100
        }
        let r = f(swatch.red), g = f(swatch.green), b = f(swatch.blue)

        var x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 95.047
        var y = (r * 0.2126 + g * 0.7152 + b * 0.0722) / 100
        var z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 108.883

        func pivot(_ t: Double) -> Double { t > 0.008856 ? cbrt(t) : 7.787 * t + 16 / 116 }
        x = pivot(x); y = pivot(y); z = pivot(z)

        return (116 * y - 16, 500 * (x - y), 200 * (y - z))
    }

    private static func deltaE(
        _ a: (Double, Double, Double),
        _ b: (Double, Double, Double)
    ) -> Double {
        let dl = a.0 - b.0, da = a.1 - b.1, db = a.2 - b.2
        return (dl * dl + da * da + db * db).squareRoot()
    }
}
