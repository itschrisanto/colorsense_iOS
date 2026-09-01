import SwiftUI

struct PaletteColor: Identifiable, Equatable {
    let id = UUID()
    let red: Double
    let green: Double
    let blue: Double
    /// Fraction of sampled pixels this color's cluster accounted for, 0...1.
    let dominance: Double

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    var hex: String {
        let r = Int((red * 255).rounded())
        let g = Int((green * 255).rounded())
        let b = Int((blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
