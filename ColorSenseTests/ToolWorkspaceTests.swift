import Testing
@testable import ColorSense

@Suite("Tool workspace")
struct ToolWorkspaceTests {
    @Test("The strip contains every view-like tool in product order")
    func panelOrder() {
        #expect(Tool.panels == [.contrast, .health, .svg, .visualizer, .schemes, .library])
    }

    /// Schemes sits before Library deliberately: Library is where you leave the palette behind and
    /// pick up another, so it reads last. Everything before it acts on the palette in hand.
    @Test("Extractor remains an action rather than a persistent panel")
    func extractorIsNotAPanel() {
        #expect(!Tool.panels.contains(.extractor))
        #expect(Set(Tool.panels.map(\.id)).count == Tool.panels.count)
    }
}
