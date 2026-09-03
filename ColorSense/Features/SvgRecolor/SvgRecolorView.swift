import SwiftUI
import UniformTypeIdentifiers

/// The SVG Recolor tool: open an SVG, map every colour it paints with onto the palette, export it.
///
/// A port of `SvgRecolorPanel.tsx`. The matching and replacement rules live in `SvgRecolor` and are
/// shared with the web; this file is the screen around them.
///
/// **Pro, as on the web.** The gate follows the precedent set by `ContrastFixSheet`: it names Pro
/// and offers no route to buy it, because there is no In-App Purchase yet and guideline 3.1.1
/// forbids pointing at an outside one. Unlike the contrast fix, which can show its whole value in
/// the locked state, there is nothing honest to show here before a file is opened, so the locked
/// state describes the tool instead of performing it.
struct SvgRecolorView: View {
    let palette: ExtractedPalette
    var isPro = false

    @Environment(\.dismiss) private var dismiss

    @State private var source: String?
    @State private var name = "recolored"
    @State private var found: [String] = []
    @State private var mapping: [String: String] = [:]
    @State private var importerIsPresented = false
    @State private var loadError: String?
    /// Which found colour is being reassigned, if any. One sheet, not one picker per row.
    @State private var editing: EditingSvgColor?

    private var recolored: String? {
        source.map { SvgRecolor.recolor($0, mapping: mapping) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !isPro {
                    locked
                } else if source == nil {
                    chooser
                } else {
                    editor
                }
            }
            .navigationTitle("SVG Recolor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if isPro, source != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Open another") { importerIsPresented = true }
                    }
                }
            }
            .fileImporter(
                isPresented: $importerIsPresented,
                allowedContentTypes: [.svg],
                allowsMultipleSelection: false
            ) { result in
                load(result)
            }
        }
    }

    // MARK: - States

    private var locked: some View {
        LaumaNotice(
            pose: .curious,
            title: "SVG Recolor is a Pro feature",
            message: "Open any SVG and remap every colour it uses onto this palette, then export it. Logos, icons and illustrations stay perfectly crisp."
        )
    }

    private var chooser: some View {
        LaumaNotice(
            pose: .curious,
            title: "Open an SVG to recolour",
            message: "Logos, icons and illustrations. Every colour the file paints with becomes a row you can point at a palette swatch."
        ) {
            Button("Choose an SVG") { importerIsPresented = true }
                .buttonStyle(.borderedProminent)
                .tint(BrandColor.coral)
        }
    }

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                preview

                HStack {
                    Text("\(found.count) \(found.count == 1 ? "colour" : "colours") found")
                        .font(BrandFont.ui(13, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Map to palette") { mapAllToPalette() }
                        .font(BrandFont.ui(13, weight: .medium))
                }

                VStack(spacing: 0) {
                    ForEach(Array(found.enumerated()), id: \.element) { index, color in
                        if index > 0 { Divider() }
                        row(for: color)
                    }
                }

                if let recolored, let file = exportURL(for: recolored) {
                    ShareLink(item: file) {
                        Label("Export recoloured SVG", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BrandColor.coral)
                    .padding(.top, 4)
                }
            }
            .padding(20)
        }
        .sheet(item: $editing) { entry in
            SvgColorPicker(
                original: entry.id,
                palette: palette.colors,
                target: Binding(
                    get: { mapping[entry.id] ?? entry.id },
                    set: { mapping[entry.id] = $0 }
                )
            )
        }
        .alert("That file could not be read", isPresented: .constant(loadError != nil)) {
            Button("OK") { loadError = nil }
        } message: {
            Text(loadError ?? "")
        }
    }

    private var preview: some View {
        ZStack {
            // Drawn here rather than in the document, so transparency in the file reads as
            // transparency rather than as whatever the page background happens to be.
            Checkerboard()
            if let recolored {
                SvgPreview(svg: recolored)
                    .padding(12)
            }
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
    }

    /// One line per colour in the file: what it is, what it becomes, and a tap to change it.
    ///
    /// Every choice used to be inline, which meant the palette's swatches were repeated under every
    /// row. On a five-colour file that is the same five circles five times over, and Chris read it,
    /// correctly, as clutter. The choosing moved into `SvgColorPicker`.
    private func row(for color: String) -> some View {
        let target = mapping[color] ?? color
        let isChanged = target.caseInsensitiveCompare(color) != .orderedSame
        return Button {
            editing = EditingSvgColor(id: color)
        } label: {
            HStack(spacing: 12) {
                swatch(hex: color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(color)
                        .brandMono(12, weight: .regular)
                        .foregroundStyle(.secondary)
                        .strikethrough(isChanged, color: .secondary)
                    if isChanged {
                        Text(target).brandMono(12, weight: .medium)
                    } else {
                        Text("Unchanged").font(BrandFont.ui(11)).foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 8)
                swatch(hex: target)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isChanged
            ? "\(color), replaced by \(target). Change"
            : "\(color), unchanged. Change")
    }

    private func swatch(hex: String) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(PaletteColor(hexString: hex, dominance: 0)?.color ?? .clear)
            .frame(width: 26, height: 26)
            .overlay {
                RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15), lineWidth: 1)
            }
    }

    // MARK: - Actions

    /// The web's `applyPalette`: found colour *i* takes palette colour *i*, wrapping round when the
    /// file uses more colours than the palette has.
    private func mapAllToPalette() {
        let hexes = palette.colors.map { $0.hex.lowercased() }
        guard !hexes.isEmpty else { return }
        for (index, color) in found.enumerated() {
            mapping[color] = hexes[index % hexes.count]
        }
    }

    private func load(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let error) = result { loadError = error.localizedDescription }
            return
        }
        // A document handed over by the picker lives outside the sandbox until it is opened.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let colors = SvgRecolor.colors(in: text)
            source = text
            found = colors
            mapping = Dictionary(uniqueKeysWithValues: colors.map { ($0, $0) })
            name = url.deletingPathExtension().lastPathComponent
            AnalyticsService.capture(.toolOpened, ["tool": "svg_loaded"])
        } catch {
            loadError = "It could not be read as text. SVG files are XML, so a binary image saved with an .svg extension will not open."
        }
    }

    /// Writes the result somewhere the share sheet can reach, named after the original.
    private func exportURL(for svg: String) -> URL? {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-recolored.svg")
        do {
            try SvgRecolor.sanitized(svg).write(to: file, atomically: true, encoding: .utf8)
            return file
        } catch {
            return nil
        }
    }
}

/// The transparency checkerboard behind the preview.
private struct Checkerboard: View {
    var square: CGFloat = 10

    var body: some View {
        Canvas { context, size in
            let light = Color(white: 0.98)
            let dark = Color(white: 0.90)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(light))
            var y: CGFloat = 0
            var row = 0
            while y < size.height {
                var x: CGFloat = (row % 2 == 0) ? 0 : square
                while x < size.width {
                    context.fill(
                        Path(CGRect(x: x, y: y, width: square, height: square)),
                        with: .color(dark)
                    )
                    x += square * 2
                }
                y += square
                row += 1
            }
        }
        .drawingGroup()
    }
}
