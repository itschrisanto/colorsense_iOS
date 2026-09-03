import Foundation

/// The Visualizer's mockups, ported from `VisualizerPanel.tsx`.
///
/// # Why these emit SVG rather than SwiftUI shapes
///
/// On the web each mockup *is* an SVG drawing. Regenerating the same markup here means the two
/// platforms cannot disagree about what a palette looks like in a business card, which is exactly
/// what the port table at the top of CLAUDE.md asks for. Redrawing eleven scenes as SwiftUI paths
/// would be several times the code and would drift the first time either side was touched.
/// `SvgPreview`, already built for SVG Recolor, renders them with JavaScript off and no network.
///
/// # `readableOn` is deliberately *not* `ContrastCalculator`
///
/// CLAUDE.md says contrast decisions route through `ContrastCalculator`, and everywhere the app
/// chooses a label colour for **its own UI**, that still holds. This is different: these scenes
/// reproduce a drawing the web already makes, and the web picks label colours with perceived
/// luminance (0.299/0.587/0.114 over a 0.55 threshold), which can disagree with a WCAG ratio on
/// mid-tones. Using the "better" rule here would mean the same palette produced a visibly different
/// picture on each platform, which is a port failure rather than an improvement. Same reasoning as
/// the `isDark()` note in CLAUDE.md, applied in the opposite direction and for the same reason:
/// match the thing being ported.
enum VisualizerScene: String, CaseIterable, Identifiable {
    case mobileUI, webLanding, dashboard
    case brandingPoster, logoGrid, businessCard, socialPost
    case typography
    case patternGeometric, patternWaves
    case abstractIllustration

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mobileUI: return "Mobile App UI"
        case .webLanding: return "Web Landing Page"
        case .dashboard: return "SaaS Dashboard"
        case .brandingPoster: return "Brand Pattern"
        case .logoGrid: return "Logo & Brand Colors"
        case .businessCard: return "Business Card"
        case .socialPost: return "Social Media Post"
        case .typography: return "Typography Poster"
        case .patternGeometric: return "Geometric Pattern"
        case .patternWaves: return "Wave Pattern"
        case .abstractIllustration: return "Abstract Illustration"
        }
    }

    enum Category: String, CaseIterable {
        case interface = "Mobile/Web UI"
        case branding = "Branding"
        case typography = "Typography"
        case pattern = "Pattern"
        case illustration = "Illustration"
    }

    var category: Category {
        switch self {
        case .mobileUI, .webLanding, .dashboard: return .interface
        case .brandingPoster, .logoGrid, .businessCard, .socialPost: return .branding
        case .typography: return .typography
        case .patternGeometric, .patternWaves: return .pattern
        case .abstractIllustration: return .illustration
        }
    }

    /// Which scenes the web gates behind Pro. Kept identical so the same palette in the same scene
    /// costs the same on both platforms.
    var isPro: Bool {
        switch self {
        case .webLanding, .businessCard, .typography: return false
        default: return true
        }
    }
}

enum VisualizerSVG {
    // The web's neutral furniture, so the scenes read as mockups rather than as palettes.
    static let frame = "#F1F3F6"
    static let surface = "#FFFFFF"
    static let hairline = "#E2E8F0"
    static let muted = "#CBD5E1"
    static let muted2 = "#94A3B8"
    static let ink = "#0F172A"

    /// Perceived luminance, matching the web. See the note on `VisualizerScene`.
    static func readableOn(_ hex: String) -> String {
        let value = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return ink }
        let r = Double((rgb >> 16) & 0xFF)
        let g = Double((rgb >> 8) & 0xFF)
        let b = Double(rgb & 0xFF)
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.55 ? ink : "#FFFFFF"
    }

    /// The web's `toFive`: the scenes index five slots, so a shorter palette repeats and a longer
    /// one is trimmed rather than crashing on the sixth lookup.
    static func five(_ hexes: [String]) -> [String] {
        guard !hexes.isEmpty else { return Array(repeating: "#CCCCCC", count: 5) }
        return (0..<5).map { hexes[$0 % hexes.count] }
    }

    private static let shadow = """
    <defs><filter id="sh" x="-30%" y="-30%" width="160%" height="160%">\
    <feDropShadow dx="0" dy="2" stdDeviation="3.5" flood-color="#0F172A" flood-opacity="0.16"/>\
    </filter></defs>
    """

    static func document(_ scene: VisualizerScene, palette: [String]) -> String {
        let c = five(palette)
        let body: String
        switch scene {
        case .mobileUI: body = mobileUI(c)
        case .webLanding: body = webLanding(c)
        case .dashboard: body = dashboard(c)
        case .brandingPoster: body = brandingPoster(c)
        case .logoGrid: body = logoGrid(c)
        case .businessCard: body = businessCard(c)
        case .socialPost: body = socialPost(c)
        case .typography: body = typography(c)
        case .patternGeometric: body = patternGeometric(c)
        case .patternWaves: body = patternWaves(c)
        case .abstractIllustration: body = abstractIllustration(c)
        }
        // `width` and `height` as well as the viewBox, on purpose. An SVG with only a viewBox has
        // no intrinsic size, and the preview's `width:auto; height:auto` then collapses it to
        // nothing: the scene renders as an empty box with no error anywhere. The web never hit this
        // because its <svg> is sized by a CSS class instead.
        return """
        <svg xmlns="http://www.w3.org/2000/svg" width="400" height="280" viewBox="0 0 400 280" \
        preserveAspectRatio="xMidYMid meet">\(shadow)\(body)</svg>
        """
    }

    // MARK: - Scenes

    private static func mobileUI(_ c: [String]) -> String {
        let onC1 = readableOn(c[0]), onC2 = readableOn(c[1])
        var rows = ""
        for i in 0..<2 {
            let y = 162 + i * 34
            rows += """
            <rect x="153" y="\(y)" width="94" height="28" rx="8" fill="#F8FAFC" stroke="\(hairline)"/>\
            <rect x="159" y="\(y + 6)" width="16" height="16" rx="5" fill="\(i == 0 ? c[1] : c[2])"/>\
            <rect x="181" y="\(y + 8)" width="40" height="4" rx="2" fill="\(ink)" opacity="0.75"/>\
            <rect x="181" y="\(y + 16)" width="56" height="3" rx="1.5" fill="\(muted2)"/>
            """
        }
        var tabs = ""
        for i in 0..<4 {
            tabs += #"<circle cx="\#(166 + i * 24)" cy="247" r="3.4" fill="\#(i == 0 ? c[0] : muted)"/>"#
        }
        return """
        <defs><clipPath id="scr"><rect x="146" y="21" width="108" height="238" rx="19"/></clipPath></defs>\
        <rect width="400" height="280" fill="\(frame)"/>\
        <rect x="139" y="14" width="122" height="252" rx="26" fill="\(ink)" filter="url(#sh)"/>\
        <rect x="146" y="21" width="108" height="238" rx="19" fill="\(surface)"/>\
        <rect x="181" y="21" width="38" height="9" rx="4.5" fill="\(ink)"/>\
        <text x="153" y="44" font-family="system-ui" font-size="6" font-weight="700" fill="\(ink)">9:41</text>\
        <rect x="236" y="39" width="11" height="6" rx="1.5" fill="\(ink)" opacity="0.7"/>\
        <text x="153" y="66" font-family="system-ui" font-size="12" font-weight="800" fill="\(ink)">Discover</text>\
        <circle cx="243" cy="61" r="8" fill="\(c[0])"/>\
        <rect x="153" y="76" width="94" height="15" rx="7.5" fill="#F1F5F9"/>\
        <circle cx="162" cy="83.5" r="3" fill="none" stroke="\(muted2)" stroke-width="1.2"/>\
        <rect x="170" y="82" width="40" height="3" rx="1.5" fill="\(muted)"/>\
        <rect x="153" y="98" width="94" height="56" rx="10" fill="\(c[0])"/>\
        <rect x="161" y="108" width="46" height="5" rx="2.5" fill="\(onC1)" opacity="0.95"/>\
        <rect x="161" y="118" width="60" height="3.5" rx="1.75" fill="\(onC1)" opacity="0.6"/>\
        <rect x="161" y="124" width="52" height="3.5" rx="1.75" fill="\(onC1)" opacity="0.6"/>\
        <rect x="161" y="135" width="40" height="13" rx="6.5" fill="\(c[1])"/>\
        <text x="181" y="144.5" font-family="system-ui" font-size="6" font-weight="800" text-anchor="middle" fill="\(onC2)">Open</text>\
        \(rows)\
        <g clip-path="url(#scr)">\
        <rect x="146" y="236" width="108" height="23" fill="\(surface)"/>\
        <rect x="146" y="236" width="108" height="1" fill="\(hairline)"/>\(tabs)</g>\
        <text x="34" y="50" font-family="system-ui" font-size="9" font-weight="800" fill="\(muted2)" letter-spacing="1">MOBILE APP</text>\
        <rect x="34" y="60" width="64" height="6" rx="3" fill="\(c[0])"/>\
        <rect x="34" y="72" width="50" height="6" rx="3" fill="\(c[1])"/>\
        <rect x="34" y="84" width="40" height="6" rx="3" fill="\(c[2])"/>
        """
    }

    private static func webLanding(_ c: [String]) -> String {
        let onC1 = readableOn(c[0])
        var stats = ""
        let labels = [("300+", "Palettes"), ("50+", "Templates"), ("1k+", "Exports")]
        for (i, s) in labels.enumerated() {
            stats += """
            <text x="\(40 + i * 62)" y="252" font-family="system-ui" font-size="13" font-weight="900" fill="\(c[i])">\(s.0)</text>\
            <text x="\(40 + i * 62)" y="261" font-family="system-ui" font-size="6.5" font-weight="600" fill="\(muted2)">\(s.1)</text>
            """
        }
        return """
        <rect width="400" height="280" fill="\(frame)"/>\
        <rect x="16" y="14" width="368" height="252" rx="12" fill="\(surface)" filter="url(#sh)"/>\
        <rect x="16" y="14" width="368" height="24" rx="12" fill="#F8FAFC"/>\
        <rect x="16" y="30" width="368" height="8" fill="#F8FAFC"/>\
        <rect x="16" y="37" width="368" height="1" fill="\(hairline)"/>\
        <circle cx="31" cy="26" r="3" fill="#FB7185"/><circle cx="42" cy="26" r="3" fill="#FBBF24"/>\
        <circle cx="53" cy="26" r="3" fill="#34D399"/>\
        <rect x="120" y="21" width="160" height="10" rx="5" fill="#EEF2F6"/>\
        <circle cx="40" cy="58" r="7" fill="\(c[0])"/>\
        <text x="51" y="62" font-family="system-ui" font-size="11" font-weight="800" fill="\(ink)">Lumina</text>\
        <rect x="228" y="55" width="22" height="5" rx="2.5" fill="\(muted)"/>\
        <rect x="258" y="55" width="22" height="5" rx="2.5" fill="\(muted)"/>\
        <rect x="288" y="55" width="22" height="5" rx="2.5" fill="\(muted)"/>\
        <rect x="322" y="50" width="50" height="17" rx="8.5" fill="\(c[0])"/>\
        <text x="347" y="61.5" font-family="system-ui" font-size="8" font-weight="800" text-anchor="middle" fill="\(onC1)">Sign up</text>\
        <text x="36" y="115" font-family="system-ui" font-size="22" font-weight="900" fill="\(ink)" letter-spacing="-0.8">Design that</text>\
        <text x="36" y="141" font-family="system-ui" font-size="22" font-weight="900" fill="\(c[0])" letter-spacing="-0.8">moves with</text>\
        <text x="36" y="167" font-family="system-ui" font-size="22" font-weight="900" fill="\(c[1])" letter-spacing="-0.8">your color.</text>\
        <rect x="37" y="182" width="180" height="5" rx="2.5" fill="\(muted)"/>\
        <rect x="37" y="192" width="150" height="5" rx="2.5" fill="\(muted)"/>\
        <rect x="37" y="206" width="80" height="24" rx="12" fill="\(c[0])"/>\
        <text x="77" y="221.5" font-family="system-ui" font-size="9" font-weight="800" text-anchor="middle" fill="\(onC1)">Get started</text>\
        <rect x="125" y="206" width="80" height="24" rx="12" fill="\(surface)" stroke="\(c[0])" stroke-width="1.5"/>\
        <text x="165" y="221.5" font-family="system-ui" font-size="9" font-weight="700" text-anchor="middle" fill="\(c[0])">Learn more</text>\
        \(stats)\
        <rect x="250" y="84" width="74" height="74" rx="16" fill="\(c[1])"/>\
        <circle cx="348" cy="112" r="26" fill="\(c[2])"/>\
        <polygon points="268,196 308,146 308,196" fill="\(c[0])"/>\
        <circle cx="300" cy="120" r="16" fill="\(c[3])"/>\
        <circle cx="344" cy="170" r="20" fill="none" stroke="\(c[0])" stroke-width="5"/>
        """
    }

    private static func brandingPoster(_ c: [String]) -> String {
        """
        <defs><clipPath id="pc"><rect x="24" y="20" width="352" height="240" rx="10"/></clipPath></defs>\
        <rect width="400" height="280" fill="\(frame)"/>\
        <rect x="24" y="20" width="352" height="240" rx="10" fill="\(c[0])" filter="url(#sh)"/>\
        <g clip-path="url(#pc)">\
        <polygon points="24,20 220,20 80,160" fill="\(c[1])"/>\
        <polygon points="376,20 376,180 180,40" fill="\(c[2])"/>\
        <polygon points="24,260 24,120 200,260" fill="\(c[3])"/>\
        <polygon points="376,260 200,260 376,110" fill="\(c[4])"/>\
        <circle cx="210" cy="148" r="46" fill="\(c[0])" opacity="0.92"/>\
        <circle cx="210" cy="148" r="26" fill="\(c[1])"/></g>\
        <text x="210" y="152" font-family="Georgia, serif" font-size="11" font-weight="900" text-anchor="middle" \
        fill="\(readableOn(c[1]))" letter-spacing="1">AURORA</text>
        """
    }

    private static func businessCard(_ c: [String]) -> String {
        let onC1 = readableOn(c[0])
        return """
        <rect width="400" height="280" fill="\(frame)"/>\
        <g transform="rotate(-6 165 120)" filter="url(#sh)">\
        <rect x="56" y="58" width="218" height="124" rx="8" fill="\(c[0])"/>\
        <circle cx="98" cy="100" r="16" fill="none" stroke="\(c[1])" stroke-width="4"/>\
        <circle cx="98" cy="100" r="5" fill="\(c[1])"/>\
        <text x="124" y="98" font-family="Georgia, serif" font-size="17" font-weight="900" fill="\(onC1)">Orbit</text>\
        <text x="124" y="112" font-family="system-ui" font-size="7" font-weight="600" fill="\(onC1)" opacity="0.7" letter-spacing="3">DESIGN STUDIO</text>\
        <rect x="124" y="148" width="120" height="3" rx="1.5" fill="\(c[1])"/></g>\
        <g transform="rotate(5 235 165)" filter="url(#sh)">\
        <rect x="128" y="104" width="218" height="124" rx="8" fill="\(surface)"/>\
        <rect x="128" y="104" width="7" height="124" fill="\(c[1])"/>\
        <text x="152" y="146" font-family="Georgia, serif" font-size="19" font-weight="800" fill="\(c[0])">Alex Rivera</text>\
        <text x="152" y="162" font-family="system-ui" font-size="8" font-weight="700" fill="\(c[2])" letter-spacing="2">CREATIVE DIRECTOR</text>\
        <rect x="152" y="172" width="150" height="2" fill="\(c[1])"/>\
        <text x="152" y="190" font-family="system-ui" font-size="8" fill="\(muted2)">alex@orbit.studio</text>\
        <text x="152" y="203" font-family="system-ui" font-size="8" fill="\(muted2)">+1 555 0142 · orbit.studio</text></g>
        """
    }

    private static func patternGeometric(_ c: [String]) -> String {
        let cells = [
            [c[0], c[1], c[2], c[0], c[4]],
            [c[1], c[4], c[0], c[2], c[1]],
            [c[2], c[0], c[3], c[1], c[0]],
            [c[0], c[2], c[1], c[4], c[2]],
        ]
        var out = #"<rect width="400" height="280" fill="\#(c[4])"/>"#
        for (ri, row) in cells.enumerated() {
            for (ci, fill) in row.enumerated() {
                let x = ci * 80, y = ri * 70
                out += #"<rect x="\#(x)" y="\#(y)" width="80" height="70" fill="\#(fill)"/>"#
                switch (ri * 5 + ci) % 4 {
                case 0: break
                case 1: out += #"<circle cx="\#(x + 40)" cy="\#(y + 35)" r="31" fill="\#(cells[ri][(ci + 2) % 5])"/>"#
                case 2: out += #"<polygon points="\#(x),\#(y) \#(x + 80),\#(y) \#(x),\#(y + 70)" fill="\#(cells[ri][(ci + 1) % 5])"/>"#
                default: out += #"<circle cx="\#(x)" cy="\#(y + 70)" r="64" fill="\#(cells[ri][(ci + 3) % 5])"/>"#
                }
            }
        }
        return out
    }

    private static func typography(_ c: [String]) -> String {
        let onC4 = readableOn(c[3])
        return """
        <rect width="400" height="280" fill="\(c[3])"/>\
        <text x="244" y="252" font-family="Georgia, serif" font-size="260" font-weight="900" fill="\(c[0])" opacity="0.12">A</text>\
        <text x="28" y="92" font-family="Georgia, serif" font-size="52" font-weight="900" fill="\(c[0])" letter-spacing="-2">Type</text>\
        <text x="28" y="140" font-family="Georgia, serif" font-size="52" font-weight="900" fill="\(onC4)" opacity="0.9" letter-spacing="-2">that</text>\
        <text x="158" y="140" font-family="Georgia, serif" font-size="52" font-weight="900" font-style="italic" fill="\(c[1])" letter-spacing="-2">speaks.</text>\
        <rect x="30" y="152" width="120" height="3" fill="\(c[2])"/>\
        <text x="30" y="178" font-family="system-ui" font-size="10" font-weight="700" fill="\(onC4)" opacity="0.85" letter-spacing="3">DISPLAY · 2026</text>\
        <text x="30" y="198" font-family="system-ui" font-size="9" fill="\(onC4)" opacity="0.6">The quick brown fox jumps over the lazy dog.</text>\
        <text x="30" y="212" font-family="system-ui" font-size="9" fill="\(onC4)" opacity="0.6">Headlines that breathe, body that reads.</text>\
        <text x="300" y="118" font-family="Georgia, serif" font-size="34" font-weight="900" fill="\(c[0])">Aa</text>\
        <text x="300" y="158" font-family="Georgia, serif" font-size="26" font-weight="800" fill="\(c[1])">Aa</text>\
        <text x="300" y="190" font-family="Georgia, serif" font-size="20" font-weight="700" fill="\(c[2])">Aa</text>
        """
    }

    private static func patternWaves(_ c: [String]) -> String {
        """
        <rect width="400" height="280" fill="\(c[4])"/>\
        <path d="M0,80 C80,40 160,120 240,80 C320,40 360,100 400,80 L400,140 L0,140 Z" fill="\(c[0])"/>\
        <path d="M0,130 C100,90 180,170 260,130 C340,90 360,150 400,130 L400,200 L0,200 Z" fill="\(c[1])" opacity="0.85"/>\
        <path d="M0,180 C90,140 200,220 290,180 C360,150 380,200 400,180 L400,250 L0,250 Z" fill="\(c[2])" opacity="0.85"/>\
        <path d="M0,220 C100,190 200,250 300,220 C360,200 380,230 400,220 L400,280 L0,280 Z" fill="\(c[3])"/>
        """
    }

    private static func abstractIllustration(_ c: [String]) -> String {
        var dots = ""
        for (i, x) in [20, 60, 110, 360, 380, 50, 340].enumerated() {
            let cy = i % 2 == 0 ? 50 + i * 6 : 230 + i * 4
            dots += #"<circle cx="\#(x)" cy="\#(cy)" r="3" fill="\#(i % 2 == 0 ? c[1] : c[0])"/>"#
        }
        return """
        <rect width="400" height="280" fill="\(c[3])"/>\
        <path d="M100,180 C50,140 80,60 160,70 C220,78 240,30 290,60 C340,90 320,160 280,180 C240,200 220,250 160,240 C110,232 130,210 100,180 Z" fill="\(c[0])"/>\
        <path d="M150,200 C120,180 130,120 180,120 C220,120 230,90 270,110 C300,130 290,180 260,190 C230,200 220,230 180,220 Z" fill="\(c[1])" opacity="0.85"/>\
        <circle cx="220" cy="150" r="42" fill="\(c[2])" opacity="0.8"/>\
        <circle cx="200" cy="140" r="14" fill="\(c[4])"/>\
        <circle cx="240" cy="160" r="8" fill="\(c[4])"/>\(dots)
        """
    }

    private static func socialPost(_ c: [String]) -> String {
        let onC2 = readableOn(c[1])
        return """
        <rect width="400" height="280" fill="\(frame)"/>\
        <rect x="78" y="16" width="244" height="248" rx="16" fill="\(surface)" filter="url(#sh)"/>\
        <circle cx="98" cy="40" r="10" fill="\(c[0])"/>\
        <rect x="114" y="34" width="64" height="6" rx="3" fill="\(ink)" opacity="0.8"/>\
        <rect x="114" y="44" width="42" height="4" rx="2" fill="\(muted2)"/>\
        <circle cx="300" cy="38" r="1.6" fill="\(muted2)"/><circle cx="306" cy="38" r="1.6" fill="\(muted2)"/>\
        <circle cx="312" cy="38" r="1.6" fill="\(muted2)"/>\
        <rect x="78" y="58" width="244" height="148" fill="\(c[1])"/>\
        <circle cx="200" cy="120" r="40" fill="\(c[2])"/>\
        <polygon points="200,86 234,150 166,150" fill="\(c[0])"/>\
        <text x="200" y="192" font-family="Georgia, serif" font-size="20" font-weight="900" text-anchor="middle" fill="\(onC2)" letter-spacing="-0.5">New Drop.</text>\
        <path d="M96 224 c-4 -5 -11 -1 -11 4 c0 5 11 11 11 11 s11 -6 11 -11 c0 -5 -7 -9 -11 -4 z" fill="\(c[0])"/>\
        <circle cx="124" cy="229" r="6" fill="none" stroke="\(ink)" stroke-width="1.6" opacity="0.5"/>\
        <path d="M146 223 l12 6 l-12 6 z" fill="none" stroke="\(ink)" stroke-width="1.6" opacity="0.5"/>\
        <rect x="300" y="223" width="12" height="13" rx="2" fill="none" stroke="\(ink)" stroke-width="1.6" opacity="0.5"/>\
        <rect x="86" y="246" width="180" height="5" rx="2.5" fill="\(muted)"/>\
        <rect x="86" y="255" width="120" height="5" rx="2.5" fill="\(muted)"/>
        """
    }

    private static func logoTile(x: Int, y: Int, fill: String) -> String {
        let on = readableOn(fill)
        let cx = x + 28, cy = y + 58
        return """
        <rect x="\(x)" y="\(y)" width="116" height="116" rx="8" fill="\(fill)"/>\
        <g fill="\(on)">\
        <polygon points="\(cx - 11),\(cy - 2) \(cx - 13),\(cy - 15) \(cx - 2),\(cy - 7)"/>\
        <polygon points="\(cx + 11),\(cy - 2) \(cx + 13),\(cy - 15) \(cx + 2),\(cy - 7)"/>\
        <circle cx="\(cx)" cy="\(cy + 1)" r="10.5"/></g>\
        <circle cx="\(cx - 4)" cy="\(cy - 1)" r="1.6" fill="\(fill)"/>\
        <circle cx="\(cx + 4)" cy="\(cy - 1)" r="1.6" fill="\(fill)"/>\
        <polygon points="\(cx),\(cy + 3) \(cx - 2),\(cy + 1) \(cx + 2),\(cy + 1)" fill="\(fill)"/>\
        <g stroke="\(on)" stroke-width="1" stroke-linecap="round">\
        <line x1="\(cx - 5)" y1="\(cy + 3)" x2="\(cx - 13)" y2="\(cy + 1)"/>\
        <line x1="\(cx - 5)" y1="\(cy + 5)" x2="\(cx - 13)" y2="\(cy + 6)"/>\
        <line x1="\(cx + 5)" y1="\(cy + 3)" x2="\(cx + 13)" y2="\(cy + 1)"/>\
        <line x1="\(cx + 5)" y1="\(cy + 5)" x2="\(cx + 13)" y2="\(cy + 6)"/></g>\
        <text x="\(x + 48)" y="\(cy + 5)" font-family="system-ui" font-size="15" font-weight="900" fill="\(on)" letter-spacing="-0.5">Hara</text>
        """
    }

    private static func logoGrid(_ c: [String]) -> String {
        let tiles = [c[0], c[1], c[2], c[3], c[4], c[1]]
        var out = #"<rect width="400" height="280" fill="\#(frame)"/>"#
        for (i, fill) in tiles.enumerated() {
            out += logoTile(x: 18 + (i % 3) * 122, y: 16 + (i / 3) * 124, fill: fill)
        }
        return out
    }

    private static func dashboard(_ c: [String]) -> String {
        let onC1 = readableOn(c[0]), onC2 = readableOn(c[1])
        var nav = ""
        for i in 0..<6 {
            let y = 50 + i * 26
            if i == 0 { nav += #"<rect x="10" y="\#(y)" width="54" height="18" rx="6" fill="\#(c[1])" opacity="0.95"/>"# }
            nav += """
            <circle cx="20" cy="\(59 + i * 26)" r="3.4" fill="\(i == 0 ? onC2 : onC1)" opacity="\(i == 0 ? 1 : 0.55)"/>\
            <rect x="29" y="\(57 + i * 26)" width="28" height="4" rx="2" fill="\(i == 0 ? onC2 : onC1)" opacity="\(i == 0 ? 1 : 0.5)"/>
            """
        }
        var kpis = ""
        let cards = [("MRR", "$12.4k", c[0]), ("Customers", "16,601", c[1]), ("Active", "33%", c[2]), ("Churn", "2%", c[3])]
        for (i, k) in cards.enumerated() {
            let x = 86 + i * 78, on = readableOn(k.2)
            kpis += """
            <g filter="url(#sh)"><rect x="\(x)" y="40" width="70" height="42" rx="8" fill="\(k.2)"/>\
            <text x="\(x + 9)" y="58" font-family="system-ui" font-size="6.5" font-weight="700" fill="\(on)" opacity="0.85">\(k.0)</text>\
            <text x="\(x + 9)" y="73" font-family="system-ui" font-size="13" font-weight="900" fill="\(on)">\(k.1)</text></g>
            """
        }
        var bars = ""
        for (i, h) in [30, 46, 26, 54, 40, 62, 48].enumerated() {
            bars += #"<rect x="\#(100 + i * 22)" y="\#(176 - h)" width="12" height="\#(h)" rx="2.5" fill="\#(i % 2 == 0 ? c[0] : c[1])"/>"#
        }
        var table = ""
        for i in 0..<3 {
            table += """
            <circle cx="100" cy="\(224 + i * 15)" r="3.5" fill="\(c[i])"/>\
            <rect x="110" y="\(221 + i * 15)" width="70" height="4" rx="2" fill="\(muted)"/>\
            <rect x="214" y="\(221 + i * 15)" width="40" height="9" rx="4.5" fill="\(c[i])" opacity="0.18"/>
            """
        }
        var map = ""
        for idx in 0..<28 {
            let gx = idx % 7, gy = idx / 7
            map += #"<circle cx="\#(290 + gx * 15)" cy="\#(224 + gy * 13)" r="2.6" fill="\#(c[0])" opacity="\#((gx + gy) % 3 != 0 ? 0.7 : 0.15)"/>"#
        }
        return """
        <rect width="400" height="280" fill="\(frame)"/>\
        <rect x="0" y="0" width="74" height="280" fill="\(c[0])"/>\
        <circle cx="20" cy="24" r="7" fill="\(c[1])"/>\
        <rect x="32" y="20" width="30" height="7" rx="3.5" fill="\(onC1)" opacity="0.85"/>\(nav)\
        <rect x="74" y="0" width="326" height="30" fill="\(surface)"/>\
        <rect x="74" y="29" width="326" height="1" fill="\(hairline)"/>\
        <text x="88" y="19" font-family="system-ui" font-size="11" font-weight="800" fill="\(ink)">Dashboard</text>\
        <rect x="250" y="9" width="110" height="13" rx="6.5" fill="#F1F5F9"/>\
        <circle cx="384" cy="15" r="7" fill="\(c[2])"/>\(kpis)\
        <rect x="86" y="92" width="180" height="96" rx="8" fill="\(surface)" filter="url(#sh)"/>\
        <rect x="96" y="102" width="44" height="5" rx="2.5" fill="\(ink)" opacity="0.8"/>\(bars)\
        <rect x="274" y="92" width="118" height="96" rx="8" fill="\(surface)" filter="url(#sh)"/>\
        <rect x="284" y="102" width="44" height="5" rx="2.5" fill="\(ink)" opacity="0.8"/>\
        <circle cx="333" cy="146" r="30" fill="none" stroke="#EEF2F6" stroke-width="12"/>\
        <circle cx="333" cy="146" r="30" fill="none" stroke="\(c[1])" stroke-width="12" stroke-dasharray="135 188" stroke-linecap="round" transform="rotate(-90 333 146)"/>\
        <text x="333" y="150" font-family="system-ui" font-size="11" font-weight="900" text-anchor="middle" fill="\(ink)">72%</text>\
        <rect x="86" y="196" width="180" height="76" rx="8" fill="\(surface)" filter="url(#sh)"/>\
        <rect x="96" y="206" width="50" height="5" rx="2.5" fill="\(ink)" opacity="0.8"/>\(table)\
        <rect x="274" y="196" width="118" height="76" rx="8" fill="\(surface)" filter="url(#sh)"/>\
        <rect x="284" y="206" width="44" height="5" rx="2.5" fill="\(ink)" opacity="0.8"/>\(map)
        """
    }
}
