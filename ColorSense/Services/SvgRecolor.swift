import Foundation

/// SVG recolouring, ported from `SvgRecolorPanel.tsx` in the web app.
///
/// This is a line-for-line port of `normalizeColor`, `extractColorsFromSvg`, `colorVariants` and
/// `recolorSvg`. If the matching or replacement rules change on one side they change on the other
/// in the same pass, or the same file recolours differently on the two platforms.
///
/// The approach is deliberately textual rather than a real XML rewrite: the file is edited in place
/// so everything the parser would not have understood, and every byte the author wrote that the
/// tool does not care about, survives untouched.
enum SvgRecolor {

    // MARK: - Reading

    /// Lower-cases, and expands the `#abc` shorthand to `#aabbcc`, so `#F00` and `#ff0000` are one
    /// colour rather than two entries in the list.
    static func normalize(_ color: String) -> String {
        let trimmed = color.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.hasPrefix("#") else { return trimmed }
        if trimmed.count == 4 {
            return "#" + trimmed.dropFirst().flatMap { [$0, $0] }
        }
        return trimmed
    }

    /// Every distinct colour the file paints with, in the order first seen.
    ///
    /// Reads `fill`, `stroke` and `stop-color` from both attributes and CSS declarations, the
    /// latter covering inline `style=` and `<style>` blocks alike. Skips the four values that name
    /// no colour: `none`, `currentcolor`, `transparent`, and any `url(...)` reference to a gradient
    /// or pattern, whose own stops are picked up separately through `stop-color`.
    static func colors(in svg: String) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []

        func collect(_ pattern: String) {
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return }
            let range = NSRange(svg.startIndex..., in: svg)
            for match in re.matches(in: svg, range: range) {
                guard let r = Range(match.range(at: 1), in: svg) else { continue }
                let value = svg[r].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !value.isEmpty,
                      value != "none", value != "currentcolor", value != "transparent",
                      !value.hasPrefix("url(")
                else { continue }
                let normalized = normalize(value)
                if seen.insert(normalized).inserted { ordered.append(normalized) }
            }
        }

        collect(#"(?:fill|stroke|stop-color)\s*=\s*["']([^"']+)["']"#)
        collect(#"(?:fill|stroke|stop-color)\s*:\s*([^;}"']+)"#)
        return ordered
    }

    // MARK: - Writing

    /// The spellings a normalised colour might actually appear as in the source text.
    ///
    /// A file written `#f00` normalises to `#ff0000`, and replacing only the long form would miss
    /// every occurrence. Shorthand is only a candidate when all three channel pairs repeat.
    static func variants(of normalized: String) -> [String] {
        var out = [normalized]
        let hex = normalized.dropFirst()
        if normalized.hasPrefix("#"), hex.count == 6,
           hex.allSatisfy({ $0.isHexDigit }) {
            let c = Array(hex)
            if c[0] == c[1], c[2] == c[3], c[4] == c[5] {
                out.append("#\(c[0])\(c[2])\(c[4])")
            }
        }
        return out
    }

    /// Rewrites the file so each mapped colour is replaced wherever it is painted.
    ///
    /// Only `fill`, `stroke` and `stop-color` are touched, in attributes and CSS declarations, so a
    /// hex that appears in an id, a comment or a piece of unrelated text is left alone.
    static func recolor(_ svg: String, mapping: [String: String]) -> String {
        var out = svg
        // Sorted so a given input always produces byte-identical output, which is what makes the
        // result testable and diffable. Dictionary order is not guaranteed.
        for from in mapping.keys.sorted() {
            guard let to = mapping[from], !to.isEmpty, from != to else { continue }
            for variant in variants(of: from) {
                let v = NSRegularExpression.escapedPattern(for: variant)
                out = replace(
                    in: out,
                    pattern: #"((?:fill|stroke|stop-color)\s*=\s*["'])\#(v)(["'])"#,
                    template: "$1\(to)$2"
                )
                out = replace(
                    in: out,
                    pattern: #"((?:fill|stroke|stop-color)\s*:\s*)\#(v)(\s*[;}"'])"#,
                    template: "$1\(to)$2"
                )
            }
        }
        return out
    }

    private static func replace(in text: String, pattern: String, template: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return text }
        return re.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: template
        )
    }

    // MARK: - Safety

    /// Strips the parts of an untrusted SVG that could do something other than draw.
    ///
    /// The web uses DOMPurify, which has no Swift equivalent, so this is the same intent rather
    /// than the same implementation: remove `<script>` and `<foreignObject>` wholesale, and drop
    /// event-handler attributes and `javascript:` URLs.
    ///
    /// **This is the second line of defence, not the first.** The preview renders in a `WKWebView`
    /// with JavaScript disabled entirely and no remote resource loading, so nothing here is relied
    /// on to make an active document safe. It exists because the file is also handed to the share
    /// sheet, where it goes on to open in applications this app does not control.
    static func sanitized(_ svg: String) -> String {
        var out = svg
        for tag in ["script", "foreignObject"] {
            out = replace(in: out, pattern: "<\(tag)\\b[\\s\\S]*?</\(tag)\\s*>", template: "")
            out = replace(in: out, pattern: "<\(tag)\\b[^>]*/\\s*>", template: "")
        }
        out = replace(in: out, pattern: #"\son[a-z]+\s*=\s*["'][^"']*["']"#, template: "")
        out = replace(in: out, pattern: #"(?:href|xlink:href)\s*=\s*["']\s*javascript:[^"']*["']"#, template: "")
        return out
    }
}
