import Foundation

/// WCAG 2.x contrast ratio math (relative luminance formula from the WCAG spec).
/// Thresholds must match vault: Claude Skill.md section 11 "WCAG Contrast Ratios".
enum ContrastCalculator {
    enum Level: Equatable {
        case fail
        case aa
        case aaa
    }

    /// Relative luminance of an sRGB color, each channel 0...1.
    static func relativeLuminance(red: Double, green: Double, blue: Double) -> Double {
        func linearize(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
    }

    /// Contrast ratio between two colors, always >= 1.0 and <= 21.0.
    static func ratio(
        r1: Double, g1: Double, b1: Double,
        r2: Double, g2: Double, b2: Double
    ) -> Double {
        let l1 = relativeLuminance(red: r1, green: g1, blue: b1)
        let l2 = relativeLuminance(red: r2, green: g2, blue: b2)
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    static func normalTextLevel(for ratio: Double) -> Level {
        if ratio >= 7.0 { return .aaa }
        if ratio >= 4.5 { return .aa }
        return .fail
    }

    static func largeTextLevel(for ratio: Double) -> Level {
        if ratio >= 4.5 { return .aaa }
        if ratio >= 3.0 { return .aa }
        return .fail
    }

    /// Non-text contrast, e.g. UI component boundaries (SC 1.4.11): passes at 3:1.
    static func nonTextPasses(_ ratio: Double) -> Bool {
        ratio >= 3.0
    }

    /// Whether white text out-contrasts black text on the given background, channels 0...1.
    /// Drives the label color on palette bands so it flips automatically per swatch.
    static func prefersLightText(onRed red: Double, green: Double, blue: Double) -> Bool {
        let againstWhite = ratio(r1: red, g1: green, b1: blue, r2: 1, g2: 1, b2: 1)
        let againstBlack = ratio(r1: red, g1: green, b1: blue, r2: 0, g2: 0, b2: 0)
        return againstWhite > againstBlack
    }

    /// The five-point plain-language grade shown on the color detail card, ported from
    /// `rateContrast()` in the web app's labColor.ts. It is a friendlier restatement of the same
    /// WCAG thresholds `normalTextLevel` uses (7.0 and 4.5), not a separate standard — keep the
    /// two in step, and keep these labels identical to the web's.
    struct Rating: Equatable {
        enum Tone: Equatable { case good, warning, bad }
        let label: String
        let tone: Tone
    }

    static func rating(for ratio: Double) -> Rating {
        if ratio >= 7.0 { return Rating(label: "GREAT 5/5", tone: .good) }
        if ratio >= 4.5 { return Rating(label: "GOOD 4/5", tone: .good) }
        if ratio >= 3.0 { return Rating(label: "OK 3/5", tone: .warning) }
        if ratio >= 2.0 { return Rating(label: "POOR 2/5", tone: .bad) }
        return Rating(label: "POOR 1/5", tone: .bad)
    }
}
