import Foundation

/// Color-space conversions, ported line-for-line from the web app's
/// `artifacts/color-palette/src/lib/colorHarmony.ts` and `lib/labColor.ts`.
///
/// The rounding and reference-white choices here are the web app's, not the "most correct" ones —
/// the point is that a hex shown in the iOS detail card reads identically to the same hex on
/// colorsense.online. Change these only alongside the web.
enum ColorMath {
    /// Hue in degrees 0..<360, saturation and lightness 0...1.
    struct HSL: Equatable {
        var hue: Double
        var saturation: Double
        var lightness: Double
    }

    /// RGB channels 0...255.
    struct RGB255: Equatable {
        var red: Double
        var green: Double
        var blue: Double
    }

    // MARK: - HSL

    static func hsl(fromRed red: Double, green: Double, blue: Double) -> HSL {
        let maxChannel = max(red, green, blue)
        let minChannel = min(red, green, blue)
        let lightness = (maxChannel + minChannel) / 2

        guard maxChannel != minChannel else {
            return HSL(hue: 0, saturation: 0, lightness: lightness)
        }

        let delta = maxChannel - minChannel
        let saturation = lightness > 0.5
            ? delta / (2 - maxChannel - minChannel)
            : delta / (maxChannel + minChannel)

        let hue: Double
        switch maxChannel {
        case red: hue = ((green - blue) / delta + (green < blue ? 6 : 0)) * 60
        case green: hue = ((blue - red) / delta + 2) * 60
        default: hue = ((red - green) / delta + 4) * 60
        }
        return HSL(hue: hue, saturation: saturation, lightness: lightness)
    }

    /// Returns sRGB channels in 0...1. Hue wraps; saturation and lightness clamp.
    static func rgb(from hsl: HSL) -> (red: Double, green: Double, blue: Double) {
        let hue = ((hsl.hue.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        let saturation = min(max(hsl.saturation, 0), 1)
        let lightness = min(max(hsl.lightness, 0), 1)

        guard saturation != 0 else { return (lightness, lightness, lightness) }

        let q = lightness < 0.5
            ? lightness * (1 + saturation)
            : lightness + saturation - lightness * saturation
        let p = 2 * lightness - q
        let hk = hue / 360

        func channel(_ offset: Double) -> Double {
            var t = offset
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1.0 / 6 { return p + (q - p) * 6 * t }
            if t < 1.0 / 2 { return q }
            if t < 2.0 / 3 { return p + (q - p) * (2.0 / 3 - t) * 6 }
            return p
        }

        // The web rounds to 8-bit here before rendering, so match that quantisation rather
        // than carrying full precision forward — otherwise generated hexes drift by a digit.
        return (
            (channel(hk + 1.0 / 3) * 255).rounded() / 255,
            (channel(hk) * 255).rounded() / 255,
            (channel(hk - 1.0 / 3) * 255).rounded() / 255
        )
    }

    // MARK: - Print and perceptual spaces

    /// CMYK percentages, each 0...100.
    static func cmyk(red: Double, green: Double, blue: Double) -> (c: Int, m: Int, y: Int, k: Int) {
        let k = 1 - max(red, green, blue)
        guard k < 1 else { return (0, 0, 0, 100) }
        return (
            Int(((1 - red - k) / (1 - k) * 100).rounded()),
            Int(((1 - green - k) / (1 - k) * 100).rounded()),
            Int(((1 - blue - k) / (1 - k) * 100).rounded()),
            Int((k * 100).rounded())
        )
    }

    private static func xyz(red: Double, green: Double, blue: Double) -> (x: Double, y: Double, z: Double) {
        func linearize(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let r = linearize(red), g = linearize(green), b = linearize(blue)
        return (
            (r * 0.4124 + g * 0.3576 + b * 0.1805) * 100,
            (r * 0.2126 + g * 0.7152 + b * 0.0722) * 100,
            (r * 0.0193 + g * 0.1192 + b * 0.9505) * 100
        )
    }

    /// CIE L*a*b* against the D65 reference white, rounded as the web app rounds it.
    static func lab(red: Double, green: Double, blue: Double) -> (l: Int, a: Int, b: Int) {
        var (x, y, z) = xyz(red: red, green: green, blue: blue)
        x /= 95.047; y /= 100.0; z /= 108.883

        func f(_ t: Double) -> Double {
            t > 0.008856 ? cbrt(t) : 7.787 * t + 16.0 / 116
        }
        let fx = f(x), fy = f(y), fz = f(z)
        return (
            Int((116 * fy - 16).rounded()),
            Int((500 * (fx - fy)).rounded()),
            Int((200 * (fy - fz)).rounded())
        )
    }

    static func lch(l: Int, a: Int, b: Int) -> (l: Int, c: Int, h: Int) {
        let aD = Double(a), bD = Double(b)
        let chroma = (aD * aD + bD * bD).squareRoot()
        var hue = atan2(bD, aD) * 180 / .pi
        if hue < 0 { hue += 360 }
        return (l, Int(chroma.rounded()), Int(hue.rounded()))
    }
}

/// One row of the detail card's Conversion grid.
struct ColorConversion: Identifiable {
    var id: String { label }
    let label: String
    let value: String
}

extension PaletteColor {
    /// The six conversions the web's detail card shows, in its order and formatting.
    var conversions: [ColorConversion] {
        let r255 = Int((red * 255).rounded())
        let g255 = Int((green * 255).rounded())
        let b255 = Int((blue * 255).rounded())
        let hsl = ColorMath.hsl(fromRed: red, green: green, blue: blue)
        let cmyk = ColorMath.cmyk(red: red, green: green, blue: blue)
        let lab = ColorMath.lab(red: red, green: green, blue: blue)
        let lch = ColorMath.lch(l: lab.l, a: lab.a, b: lab.b)

        return [
            ColorConversion(label: "HEX", value: String(hex.dropFirst())),
            ColorConversion(label: "RGB", value: "\(r255), \(g255), \(b255)"),
            ColorConversion(
                label: "HSL",
                value: "\(Int(hsl.hue.rounded())), \(Int((hsl.saturation * 100).rounded())), \(Int((hsl.lightness * 100).rounded()))"
            ),
            ColorConversion(label: "CMYK", value: "\(cmyk.c), \(cmyk.m), \(cmyk.y), \(cmyk.k)"),
            ColorConversion(label: "LAB", value: "\(lab.l), \(lab.a), \(lab.b)"),
            ColorConversion(label: "LCH", value: "\(lch.l), \(lch.c), \(lch.h)"),
        ]
    }
}
