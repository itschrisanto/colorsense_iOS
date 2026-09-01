import SwiftUI
import Observation

@Observable
final class WCAGCheckerViewModel {
    var foreground: Color = .black
    var background: Color = .white

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
