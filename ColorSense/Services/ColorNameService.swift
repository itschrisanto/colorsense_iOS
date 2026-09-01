import Foundation

/// Names a color from the same 1,566-entry Name That Color dataset the web app bundles
/// (`artifacts/color-palette/src/lib/colorNames.ts`), using the same nearest-neighbour rule:
/// smallest squared Euclidean distance in 0...255 RGB.
///
/// Plain RGB distance is not the most perceptually accurate metric — Lab would be better — but
/// it is what the web app uses, and a given hex must never get one name on the web and a
/// different one on iOS. Don't "improve" this metric without changing the web app in step.
enum ColorNameService {
    private struct Entry {
        let red: Double
        let green: Double
        let blue: Double
        let name: String
    }

    private static let entries: [Entry] = loadEntries()

    /// Closest dataset name for an sRGB color, channels 0...1.
    static func name(red: Double, green: Double, blue: Double) -> String {
        let r = red * 255, g = green * 255, b = blue * 255
        var bestDistance = Double.infinity
        var best = "Unknown"
        for entry in entries {
            let dr = r - entry.red, dg = g - entry.green, db = b - entry.blue
            let distance = dr * dr + dg * dg + db * db
            if distance < bestDistance {
                bestDistance = distance
                best = entry.name
            }
        }
        return best
    }

    private static func loadEntries() -> [Entry] {
        guard
            let url = Bundle.main.url(forResource: "ColorNames", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let pairs = try? JSONDecoder().decode([[String]].self, from: data)
        else {
            print("⚠️ ColorNames.json missing or malformed — colors will fall back to \"Unknown\".")
            return []
        }
        return pairs.compactMap { pair in
            guard pair.count == 2, let hex = UInt32(pair[0], radix: 16) else { return nil }
            return Entry(
                red: Double((hex >> 16) & 0xFF),
                green: Double((hex >> 8) & 0xFF),
                blue: Double(hex & 0xFF),
                name: pair[1]
            )
        }
    }
}
