import Testing
@testable import ColorSense

/// Pins the port to what `SvgRecolorPanel.tsx` does. These are the rules that have to agree across
/// the two platforms, so a failure here means the same file would recolour differently on the web.
@Suite("SVG recolor")
struct SvgRecolorTests {

    @Test("Shorthand hex expands the way the web normalises it")
    func normalizeExpandsShorthand() {
        #expect(SvgRecolor.normalize("#F00") == "#ff0000")
        #expect(SvgRecolor.normalize("  #AaBbCc ") == "#aabbcc")
        // Named colours are lower-cased and otherwise left alone, since the web does not resolve
        // them to hex either.
        #expect(SvgRecolor.normalize("RebeccaPurple") == "rebeccapurple")
    }

    @Test("Colors are read from attributes and from CSS, and deduplicated")
    func collectsFromBothSyntaxes() {
        let svg = """
        <svg><style>.a { fill: #F00; stroke:#00ff00 }</style>
        <rect fill="#ff0000" stroke='#0F0'/>
        <stop stop-color="#0000FF"/></svg>
        """
        // #F00 and #ff0000 are one colour; #00ff00 and #0F0 likewise.
        #expect(SvgRecolor.colors(in: svg) == ["#ff0000", "#00ff00", "#0000ff"])
    }

    @Test("The four non-colours are skipped")
    func skipsNonColors() {
        let svg = """
        <svg><rect fill="none" stroke="currentColor"/>
        <rect fill="transparent" stroke="url(#grad)"/>
        <rect fill="#123456"/></svg>
        """
        #expect(SvgRecolor.colors(in: svg) == ["#123456"])
    }

    @Test("Shorthand is a replacement candidate only when every channel pair repeats")
    func variantsOfShorthand() {
        #expect(SvgRecolor.variants(of: "#ff0000") == ["#ff0000", "#f00"])
        #expect(SvgRecolor.variants(of: "#123456") == ["#123456"])
    }

    @Test("Recolor rewrites both syntaxes, including the shorthand spelling")
    func recolorsEverySpelling() {
        let svg = """
        <svg><style>.a { fill: #f00; }</style><rect fill="#FF0000" stroke='#f00'/></svg>
        """
        let out = SvgRecolor.recolor(svg, mapping: ["#ff0000": "#00b3a4"])
        #expect(!out.lowercased().contains("#ff0000"))
        #expect(!out.lowercased().contains("#f00\""))
        #expect(out.components(separatedBy: "#00b3a4").count - 1 == 3)
    }

    @Test("A hex that is not painting anything is left alone")
    func leavesUnrelatedTextAlone() {
        let svg = ##"<svg><g id="#ff0000"><rect fill="#ff0000"/></g><!-- #ff0000 --></svg>"##
        let out = SvgRecolor.recolor(svg, mapping: ["#ff0000": "#000000"])
        #expect(out.contains(##"id="#ff0000""##))
        #expect(out.contains("<!-- #ff0000 -->"))
        #expect(out.contains(##"fill="#000000""##))
    }

    @Test("Identical input gives identical output, so the result is diffable")
    func outputIsDeterministic() {
        let svg = ##"<svg><rect fill="#111111"/><rect fill="#222222"/></svg>"##
        let mapping = ["#111111": "#aaaaaa", "#222222": "#bbbbbb"]
        #expect(SvgRecolor.recolor(svg, mapping: mapping) == SvgRecolor.recolor(svg, mapping: mapping))
    }

    @Test("The preview shape comes from viewBox first, then width and height")
    func readsAspectRatio() {
        #expect(SvgRecolor.aspectRatio(of: #"<svg viewBox="0 0 200 100">"#) == 2)
        // Commas are legal separators, and a non-zero origin must not be mistaken for the size.
        #expect(SvgRecolor.aspectRatio(of: #"<svg viewBox="10,10,300,100">"#) == 3)
        // No viewBox: fall back to the attributes, ignoring units.
        #expect(SvgRecolor.aspectRatio(of: #"<svg width="50px" height="100px">"#) == 0.5)
        // viewBox wins when both are present.
        #expect(SvgRecolor.aspectRatio(of: #"<svg width="10" height="10" viewBox="0 0 400 100">"#) == 4)
    }

    @Test("A file that says nothing usable about its shape returns nil, not a crash")
    func aspectRatioIsOptional() {
        #expect(SvgRecolor.aspectRatio(of: "<svg>") == nil)
        // A zero height would be a divide by zero, so it counts as saying nothing.
        #expect(SvgRecolor.aspectRatio(of: #"<svg viewBox="0 0 100 0">"#) == nil)
        #expect(SvgRecolor.aspectRatio(of: #"<svg width="0" height="10">"#) == nil)
    }

    @Test("Sanitising removes what could act rather than draw")
    func sanitiseStripsActiveContent() {
        let svg = """
        <svg><script>alert(1)</script><foreignObject><b>x</b></foreignObject>
        <rect fill="#ff0000" onload="steal()" onclick='x()'/>
        <a href="javascript:void(0)">t</a></svg>
        """
        let out = SvgRecolor.sanitized(svg)
        #expect(!out.contains("<script"))
        #expect(!out.contains("foreignObject"))
        #expect(!out.contains("onload"))
        #expect(!out.contains("onclick"))
        #expect(!out.lowercased().contains("javascript:"))
        // The drawing survives.
        #expect(out.contains(##"fill="#ff0000""##))
    }
}
