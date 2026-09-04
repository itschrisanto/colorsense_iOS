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
    /// Whether this is the panel currently on screen. Its preview is a `WKWebView`, and rendering
    /// one behind an invisible panel is real work for nothing.
    var isActive = true

    @Environment(\.dismiss) private var dismiss

    @State private var source: String?
    @State private var name = "recolored"
    @State private var found: [String] = []
    @State private var mapping: [String: String] = [:]
    @State private var importerIsPresented = false
    @State private var loadError: String?
    /// Which found colour is being reassigned, if any. One sheet, not one picker per row.
    @State private var editing: EditingSvgColor?
    @State private var isConfirmingExit = false

    private var recolored: String? {
        source.map { SvgRecolor.recolor($0, mapping: mapping) }
    }

    var body: some View {
            Group {
                if !isPro {
                    locked
                } else if source == nil {
                    chooser
                } else {
                    editor
                }
            }
            // On the whole screen, not on the editor.
            //
            // It was attached inside `editor`, which is the one state that cannot be showing when a
            // load fails: a failure means there is no source, so the chooser is up and the alert
            // was not in the hierarchy at all. The message was therefore unreachable in exactly the
            // case it existed for. A real binding rather than `.constant`, so any dismissal clears
            // it and not just the button.
            .alert(
                "That file could not be read",
                isPresented: Binding(get: { loadError != nil }, set: { if !$0 { loadError = nil } })
            ) {
                Button("OK") { loadError = nil }
            } message: {
                Text(loadError ?? "")
            }
            .confirmsDiscard(
                hasWork: source != nil,
                message: "The file you opened and the colors you have mapped are only here. Exporting is the only thing that keeps them.",
                isAsking: $isConfirmingExit
            ) {
                dismiss()
            }
            .fileImporter(
                isPresented: $importerIsPresented,
                allowedContentTypes: [.svg],
                allowsMultipleSelection: false
            ) { result in
                load(result)
            }
    }

    // MARK: - States

    private var locked: some View {
        LaumaNotice(
            pose: .curious,
            title: "SVG Recolor is a Pro feature",
            message: "Open any SVG and remap every color it uses onto this palette, then export it. Logos, icons and illustrations stay perfectly crisp."
        )
    }

    private var chooser: some View {
        LaumaNotice(
            pose: .curious,
            title: "Open an SVG to recolor",
            message: "Logos, icons and illustrations. Every color the file paints with becomes a row you can point at a palette swatch."
        ) {
            Button("Choose an SVG") { importerIsPresented = true }
                .buttonStyle(.primaryAction)
        }
    }

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                preview

                if found.isEmpty {
                    // Legitimate and not an error: a file can paint entirely with `currentColor`,
                    // or with gradients referenced by url(), and there is nothing here to remap.
                    Text("This file has no colors to change. It paints with currentColor or with gradients only, so there is nothing to remap.")
                        .font(BrandFont.ui(14))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    // Was a toolbar item; the toolbar belongs to `ToolWorkspace` now and carries
                    // navigation only.
                    Button("Open another") { importerIsPresented = true }
                        .font(BrandFont.ui(13, weight: .medium))
                    Spacer()
                }

                HStack {
                    Text("\(found.count) \(found.count == 1 ? "color" : "colors") found")
                        .font(BrandFont.ui(13, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Map to palette") { mapAllToPalette() }
                        .font(BrandFont.ui(13, weight: .medium))
                        .disabled(found.isEmpty)
                }

                VStack(spacing: 0) {
                    ForEach(Array(found.enumerated()), id: \.element) { index, color in
                        if index > 0 { Divider() }
                        row(for: color)
                    }
                }

                if let recolored, let file = exportURL(for: recolored) {
                    // `ShareLink` is a Button underneath, so the house style applies to it the
                    // same way it does to every other primary action.
                    ShareLink(item: file) {
                        Label("Export recolored SVG", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.primaryAction)
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

    }

    /// The preview takes the artwork's own shape rather than a fixed box.
    ///
    /// It used to be a flat 240pt tall whatever the file was, so a wide banner sat small between
    /// two bands of checkerboard and a tall logo sat narrow between two more. Reading the `viewBox`
    /// lets the canvas match what was drawn, which is both a better use of the space and a truer
    /// preview.
    ///
    /// Clamped at both ends. Unclamped, a long banner collapses to a sliver and a tall crest pushes
    /// every row off the screen, and the ratio in a file is not always sane.
    private var previewHeight: CGFloat {
        let ratio = source.flatMap(SvgRecolor.aspectRatio(of:)) ?? 1
        let width: CGFloat = 320
        return min(max(width / ratio, 150), 330)
    }

    private var preview: some View {
        ZStack {
            // Drawn here rather than in the document, so transparency in the file reads as
            // transparency rather than as whatever the page background happens to be.
            Checkerboard()
            if isActive, let recolored {
                SvgPreview(svg: recolored)
                    .padding(12)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: previewHeight)
        .animation(.easeInOut(duration: 0.2), value: previewHeight)
        // The web view cannot describe itself, and VoiceOver reading its DOM would be worse than
        // useless. The rows below carry the actual information.
        .accessibilityElement()
        .accessibilityLabel("Preview of the recolored file")
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
            AnalyticsService.capture(.svgFileOpened, ["colors": String(colors.count)])
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
///
/// Both greys follow the appearance. Hardcoded light values glowed in dark mode: a bright panel in
/// the middle of a dark screen, which reads as a rendering fault rather than as "nothing here".
private struct Checkerboard: View {
    var square: CGFloat = 10

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            let light = colorScheme == .dark ? Color(white: 0.17) : Color(white: 0.98)
            let dark = colorScheme == .dark ? Color(white: 0.24) : Color(white: 0.90)
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
