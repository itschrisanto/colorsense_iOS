import UIKit

/// Writes a palette out in each Pro export format.
///
/// Everything is produced on-device with no third-party dependencies: the text formats are
/// string building, PDF uses UIKit's own renderer, and the two binary formats (ASE, Procreate)
/// are written byte by byte — both are simple enough not to justify a library.
///
/// Each format returns a file URL in the temporary directory so `ShareLink` can hand it to any
/// app with its real filename and extension intact. Sharing raw `Data` would lose the name.
enum PaletteFileExporter {
    static func file(_ format: PaletteFileFormat, for palette: ExtractedPalette) -> URL? {
        let data: Data?
        switch format {
        case .tailwind: data = Data(tailwind(palette).utf8)
        case .code: data = Data(code(palette).utf8)
        case .svg: data = Data(svg(palette).utf8)
        case .embed: data = Data(embed(palette).utf8)
        case .pdf: data = pdf(palette)
        case .ase: data = ASEWriter.data(for: palette)
        case .procreate: data = ProcreateSwatchesWriter.data(for: palette)
        }

        guard let data else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ColorSense palette")
            .appendingPathExtension(format.fileExtension)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Text formats

    /// Matches the shape of `buildTailwindConfig` in the web's BrandKitPanel, so a config
    /// generated on either platform drops into a project the same way.
    private static func tailwind(_ palette: ExtractedPalette) -> String {
        let entries = zip(uniqueSlugs(for: palette), palette.colors).map { slug, swatch in
            "        \(slug): \"\(swatch.hex.lowercased())\","
        }.joined(separator: "\n")

        return """
        /** @type {import('tailwindcss').Config} */
        export default {
          theme: {
            extend: {
              colors: {
        \(entries)
              },
            },
          },
        };

        """
    }

    /// CSS, SCSS and JSON in one file — the three shapes a developer is most likely to paste,
    /// rather than making them export three times.
    private static func code(_ palette: ExtractedPalette) -> String {
        let slugs = uniqueSlugs(for: palette)
        let css = zip(slugs, palette.colors).map { slug, swatch in
            "  --\(slug): \(swatch.hex.lowercased());"
        }.joined(separator: "\n")

        let scss = zip(slugs, palette.colors).map { slug, swatch in
            "$\(slug): \(swatch.hex.lowercased());"
        }.joined(separator: "\n")

        let json = zip(slugs, palette.colors).map { slug, swatch in
            "  \"\(slug)\": \"\(swatch.hex.lowercased())\""
        }.joined(separator: ",\n")

        return """
        /* CSS custom properties */
        :root {
        \(css)
        }

        /* SCSS variables */
        \(scss)

        /* JSON */
        {
        \(json)
        }

        """
    }

    private static func svg(_ palette: ExtractedPalette) -> String {
        let swatchWidth = 200
        let height = 240
        let width = swatchWidth * max(palette.colors.count, 1)

        let rects = palette.colors.enumerated().map { index, swatch in
            let x = index * swatchWidth
            return """
              <rect x="\(x)" y="0" width="\(swatchWidth)" height="\(height - 60)" fill="\(swatch.hex)"/>
              <text x="\(x + 16)" y="\(height - 34)" font-family="DM Sans, Helvetica, Arial, sans-serif" font-size="18" font-weight="700" fill="#111111">\(escaped(swatch.name))</text>
              <text x="\(x + 16)" y="\(height - 12)" font-family="Menlo, monospace" font-size="14" fill="#666666">\(swatch.hex)</text>
            """
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="\(width)" height="\(height)" viewBox="0 0 \(width) \(height)">
        \(rects)
        </svg>

        """
    }

    private static func embed(_ palette: ExtractedPalette) -> String {
        let cells = palette.colors.map { swatch in
            """
              <div style="flex:1;min-width:0">
                <div style="height:96px;background:\(swatch.hex)"></div>
                <div style="padding:8px 4px;font:600 13px/1.3 system-ui,sans-serif">\(escaped(swatch.name))</div>
                <div style="padding:0 4px 8px;font:400 12px/1.3 ui-monospace,monospace;color:#666">\(swatch.hex)</div>
              </div>
            """
        }.joined(separator: "\n")

        return """
        <!-- ColorSense palette -->
        <div style="display:flex;gap:8px;max-width:720px;font-family:system-ui,sans-serif">
        \(cells)
        </div>

        """
    }

    // MARK: - PDF

    @MainActor
    private static func pdfOnMain(_ palette: ExtractedPalette) -> Data {
        // A4 at 72dpi, the size a print dialog expects by default.
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            context.beginPage()
            let ctx = context.cgContext

            let margin: CGFloat = 48
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 26, weight: .bold),
                .foregroundColor: UIColor.black,
            ]
            NSString(string: "ColorSense palette").draw(
                at: CGPoint(x: margin, y: margin), withAttributes: titleAttributes
            )

            let count = max(palette.colors.count, 1)
            let top = margin + 56
            let available = pageRect.height - top - margin
            let rowHeight = min(available / CGFloat(count), 96)

            for (index, swatch) in palette.colors.enumerated() {
                let y = top + CGFloat(index) * rowHeight
                let swatchRect = CGRect(x: margin, y: y, width: 120, height: rowHeight - 12)
                ctx.setFillColor(UIColor(swatch.color).cgColor)
                ctx.fill(swatchRect)

                NSString(string: swatch.name).draw(
                    at: CGPoint(x: margin + 140, y: y + 8),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                        .foregroundColor: UIColor.black,
                    ]
                )
                NSString(string: swatch.hex).draw(
                    at: CGPoint(x: margin + 140, y: y + 30),
                    withAttributes: [
                        .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                        .foregroundColor: UIColor.darkGray,
                    ]
                )
            }
        }
    }

    private static func pdf(_ palette: ExtractedPalette) -> Data? {
        MainActor.assumeIsolated { pdfOnMain(palette) }
    }

    // MARK: - Helpers

    /// One slug per swatch, guaranteed unique across the palette.
    ///
    /// Two swatches can share a nearest-colour name — a palette with two near-blacks both resolve
    /// to "Charade" — and a duplicate key silently drops a colour in Tailwind and JSON, or is
    /// overridden by the later declaration in CSS. Collisions get a numeric suffix.
    private static func uniqueSlugs(for palette: ExtractedPalette) -> [String] {
        var seen: [String: Int] = [:]
        return palette.colors.enumerated().map { index, swatch in
            let base = slug(swatch.name, fallbackIndex: index)
            let occurrence = (seen[base] ?? 0) + 1
            seen[base] = occurrence
            return occurrence == 1 ? base : "\(base)-\(occurrence)"
        }
    }

    /// Lowercase, hyphenated, ASCII-only — safe as a CSS custom property, a Tailwind key and a
    /// JSON key alike.
    private static func slug(_ name: String, fallbackIndex: Int) -> String {
        let allowed = name.lowercased().map { character -> Character in
            character.isLetter || character.isNumber ? character : "-"
        }
        let collapsed = String(allowed)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return collapsed.isEmpty ? "color-\(fallbackIndex + 1)" : collapsed
    }

    private static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
