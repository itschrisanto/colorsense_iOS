import Testing
@testable import ColorSense

/// Pins the parts of the Visualizer port that must agree with `VisualizerPanel.tsx`.
@Suite("Visualizer")
struct VisualizerTests {

    @Test("Label colours use the web's perceived-luminance rule, not a WCAG ratio")
    func readableOnMatchesTheWeb() {
        // (0.299r + 0.587g + 0.114b) / 255 > 0.55 picks ink, otherwise white.
        #expect(VisualizerSVG.readableOn("#FFFFFF") == "#0F172A")
        #expect(VisualizerSVG.readableOn("#000000") == "#FFFFFF")
        // Deliberately checked near the threshold, which is where this rule and a WCAG ratio can
        // disagree. Matching the web is the point; see the note on VisualizerScene.
        #expect(VisualizerSVG.readableOn("#4ECDC4") == "#0F172A")
        #expect(VisualizerSVG.readableOn("#7C6DEB") == "#FFFFFF")
    }

    @Test("A palette is padded or trimmed to the five slots the scenes index")
    func fiveSlots() {
        #expect(VisualizerSVG.five(["#111111", "#222222"]) ==
                ["#111111", "#222222", "#111111", "#222222", "#111111"])
        #expect(VisualizerSVG.five(["#1", "#2", "#3", "#4", "#5", "#6"]).count == 5)
        // An empty palette must not crash a scene that indexes five colours.
        #expect(VisualizerSVG.five([]).count == 5)
    }

    @Test("Every scene renders a complete SVG carrying the palette")
    func everySceneRenders() {
        let palette = ["#FF6B6B", "#4ECDC4", "#FFD93D", "#7C6DEB", "#2B2A26"]
        for scene in VisualizerScene.allCases {
            let svg = VisualizerSVG.document(scene, palette: palette)
            #expect(svg.hasPrefix("<svg"))
            #expect(svg.hasSuffix("</svg>"))
            #expect(svg.contains("viewBox=\"0 0 400 280\""))
            // Every scene uses at least the first three palette entries.
            #expect(svg.contains("#FF6B6B"), "\(scene.rawValue) never uses the first colour")
        }
    }

    @Test("The free and Pro split matches the web's registry")
    func proSplit() {
        let free = VisualizerScene.allCases.filter { !$0.isPro }
        #expect(Set(free) == Set([.webLanding, .businessCard, .typography]))
        #expect(VisualizerScene.allCases.count == 11)
    }

    @Test("A short palette still produces a scene rather than crashing")
    func handlesShortPalette() {
        let svg = VisualizerSVG.document(.dashboard, palette: ["#123456"])
        #expect(svg.contains("#123456"))
        #expect(svg.hasSuffix("</svg>"))
    }
}
