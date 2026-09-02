import SwiftUI

struct PaletteColor: Identifiable, Equatable, Codable {
    /// Per-run identity for SwiftUI, and assignable on purpose.
    ///
    /// Generate replaces every unlocked swatch with a freshly built one. With a fresh id each
    /// time, SwiftUI saw that as a band being destroyed and a different band appearing, so the
    /// colours could only pop. `PaletteStore.generate()` carries the old id onto the replacement
    /// so the band stays the same band and its colour animates instead. Locked swatches keep
    /// their identity for free, because generate keeps the instance itself.
    var id = UUID()
    let red: Double
    let green: Double
    let blue: Double
    /// Fraction of sampled pixels this color's cluster accounted for, 0...1. Generated palettes
    /// inherit the dominance of the swatch they were derived from.
    let dominance: Double
    /// Closest Name That Color match, e.g. "Shuttle Gray". Resolved once here rather than as a
    /// computed property, since naming scans the whole 1,566-entry dataset and SwiftUI would
    /// otherwise redo that scan on every body evaluation.
    private let inferredName: String
    /// A name supplied by the user when the color is saved to their account. Extracted and
    /// generated colors keep using the nearest Name That Color match.
    let customName: String?
    /// Locked swatches survive Generate untouched, and become the anchors the regenerated
    /// swatches are derived from — locking is how the user steers a run.
    var isLocked: Bool = false

    init(
        red: Double,
        green: Double,
        blue: Double,
        dominance: Double,
        isLocked: Bool = false,
        customName: String? = nil
    ) {
        self.red = red.clampedToUnit
        self.green = green.clampedToUnit
        self.blue = blue.clampedToUnit
        self.dominance = dominance
        self.isLocked = isLocked
        self.inferredName = ColorNameService.name(red: self.red, green: self.green, blue: self.blue)
        self.customName = customName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    var name: String { customName ?? inferredName }

    /// `id` and the inferred name are deliberately not persisted — `id` is per-run identity for
    /// SwiftUI, and the inferred name is derived. A user-supplied name is persisted so a saved
    /// color keeps its identity when reused in the workspace.
    private enum CodingKeys: String, CodingKey {
        case red, green, blue, dominance, isLocked, customName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            red: try container.decode(Double.self, forKey: .red),
            green: try container.decode(Double.self, forKey: .green),
            blue: try container.decode(Double.self, forKey: .blue),
            dominance: try container.decode(Double.self, forKey: .dominance),
            isLocked: try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false,
            customName: try container.decodeIfPresent(String.self, forKey: .customName)
        )
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    var hex: String {
        let r = Int((red * 255).rounded())
        let g = Int((green * 255).rounded())
        let b = Int((blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// Black or white, whichever WCAG says reads better on this color. Labels drawn on a
    /// palette band use this so they stay legible on both a near-black and a pale swatch.
    var legibleForeground: Color {
        ContrastCalculator.prefersLightText(onRed: red, green: green, blue: blue) ? .white : .black
    }
}

extension PaletteColor {
    init?(
        hexString: String,
        dominance: Double,
        isLocked: Bool = false,
        customName: String? = nil
    ) {
        var value = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        } else if value.lowercased().hasPrefix("0x") {
            value.removeFirst(2)
        }

        guard value.count == 6, let hex = UInt32(value, radix: 16) else { return nil }
        self.init(
            hex: hex,
            dominance: dominance,
            isLocked: isLocked,
            customName: customName
        )
    }

    init(
        hex: UInt32,
        dominance: Double,
        isLocked: Bool = false,
        customName: String? = nil
    ) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            dominance: dominance,
            isLocked: isLocked,
            customName: customName
        )
    }

    init(color: Color, dominance: Double = 0, customName: String? = nil) {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            self.init(hex: 0x808080, dominance: dominance, customName: customName)
            return
        }
        self.init(
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            dominance: dominance,
            customName: customName
        )
    }

    /// Contrast against pure white and pure black, as the detail card's Accessibility rows.
    var accessibilityRows: [(label: String, ratio: Double, rating: ContrastCalculator.Rating)] {
        let onWhite = ContrastCalculator.ratio(
            r1: red, g1: green, b1: blue, r2: 1, g2: 1, b2: 1
        )
        let onBlack = ContrastCalculator.ratio(
            r1: red, g1: green, b1: blue, r2: 0, g2: 0, b2: 0
        )
        return [
            ("On white", onWhite, ContrastCalculator.rating(for: onWhite)),
            ("On black", onBlack, ContrastCalculator.rating(for: onBlack)),
        ]
    }
}

private extension Double {
    var clampedToUnit: Double { min(max(self, 0), 1) }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
