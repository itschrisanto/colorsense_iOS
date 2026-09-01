import SwiftUI
import ClerkKit

/// Adds either a newly chosen color or a named color saved in the user's account at a specific
/// palette seam. The sheet owns loading and insertion so the full-bleed palette only needs to
/// carry the requested index.
struct AddColorView: View {
    let insertionIndex: Int

    @Environment(PaletteStore.self) private var store
    @Environment(Clerk.self) private var clerk
    @Environment(\.dismiss) private var dismiss

    @State private var customColor: Color
    @State private var hexDigits: String
    @State private var hexError: String?
    @State private var savedColors: [SavedPaletteService.SavedColor] = []
    @State private var loadState: LoadState = .loading
    @FocusState private var hexIsFocused: Bool

    private enum LoadState: Equatable {
        case loading
        case loaded
        case signedOut
        case failed(String)
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    init(insertionIndex: Int, initialSwatch: PaletteColor) {
        self.insertionIndex = insertionIndex
        _customColor = State(initialValue: initialSwatch.color)
        _hexDigits = State(initialValue: String(initialSwatch.hex.dropFirst()))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    customColorSection
                    savedColorSection
                }
                .padding(20)
            }
            .navigationTitle("Add color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await loadSavedColors() }
        }
        .presentationDetents([.large, .medium])
        .presentationDragIndicator(.visible)
    }

    private var customColorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Create a color")
                Spacer()
                Text("\(store.palette.colors.count) of \(PaletteStore.maximumColorCount) colors")
                    .font(BrandFont.ui(11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Keep the visible name, hex and inserted value byte-for-byte aligned with the text
            // field. Converting an sRGB `Color` back through `UIColor` can otherwise move a
            // channel by one due to floating-point color-space conversion.
            let swatch = PaletteColor(hexString: hexDigits, dominance: 0)
                ?? PaletteColor(color: customColor)
            VStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(customColor)
                    .frame(height: 104)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
                    }

                HStack(alignment: .firstTextBaseline) {
                    Text(swatch.name)
                        .font(BrandFont.ui(16, weight: .medium))
                    Spacer()
                    Text(swatch.hex)
                        .font(BrandFont.mono(13))
                        .foregroundStyle(.secondary)
                }

                colorControls

                Button {
                    add(swatch)
                } label: {
                    Label("Add this color", systemImage: "plus")
                        .font(BrandFont.ui(15, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(BrandColor.coral, in: RoundedRectangle(cornerRadius: 12))
                .disabled(!hexIsValid)
                .opacity(hexIsValid ? 1 : 0.55)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var colorControls: some View {
        VStack(spacing: 0) {
            ColorPicker(selection: $customColor, supportsOpacity: false) {
                Label("Color wheel and sliders", systemImage: "paintpalette")
                    .font(BrandFont.ui(14, weight: .medium))
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            .onChange(of: customColor) { _, color in
                let newDigits = String(PaletteColor(color: color).hex.dropFirst())
                if hexDigits != newDigits { hexDigits = newDigits }
                hexError = nil
            }

            Divider().padding(.leading, 12)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("#")
                        .font(BrandFont.mono(15, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("RRGGBB", text: $hexDigits)
                        .font(BrandFont.mono(15, weight: .medium))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .submitLabel(.done)
                        .focused($hexIsFocused)
                        .onSubmit { validateHex() }
                        .onChange(of: hexIsFocused) { _, isFocused in
                            if !isFocused { validateHex() }
                        }
                        .onChange(of: hexDigits) { _, value in
                            updateFromTypedHex(value)
                        }

                    PasteButton(payloadType: String.self) { values in
                        if let value = values.first { applyPastedHex(value) }
                    }
                    .labelStyle(.titleAndIcon)
                    .tint(BrandColor.coral)
                }

                if let hexError {
                    Text(hexError)
                        .font(BrandFont.ui(11))
                        .foregroundStyle(.red)
                } else {
                    Text("Type or paste a six-digit hex value.")
                        .font(BrandFont.ui(11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var savedColorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Saved colors")

            switch loadState {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            case .signedOut:
                helperMessage("Sign in from Account to reuse colors saved across your devices.")
            case .failed(let message):
                VStack(spacing: 10) {
                    helperMessage(message)
                    Button("Try again") { Task { await loadSavedColors() } }
                        .font(BrandFont.ui(14, weight: .medium))
                }
                .frame(maxWidth: .infinity)
            case .loaded where savedColors.isEmpty:
                helperMessage("Save a color from its detail sheet and it will appear here.")
            case .loaded:
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(savedColors) { saved in
                        savedColorButton(saved)
                    }
                }
            }
        }
    }

    private func savedColorButton(_ saved: SavedPaletteService.SavedColor) -> some View {
        Button {
            add(saved.swatch)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 11)
                    .fill(saved.swatch.color)
                    .frame(height: 76)
                    .overlay {
                        RoundedRectangle(cornerRadius: 11)
                            .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                    }
                Text(saved.name)
                    .font(BrandFont.ui(14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(saved.swatch.hex)
                    .font(BrandFont.mono(11))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(saved.name), \(saved.swatch.hex)")
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(BrandFont.ui(11, weight: .bold))
            .foregroundStyle(.secondary)
    }

    private func helperMessage(_ message: String) -> some View {
        Text(message)
            .font(BrandFont.ui(14))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func add(_ swatch: PaletteColor) {
        guard hexIsValid else {
            validateHex()
            return
        }
        guard store.insert(swatch, at: insertionIndex) else { return }
        dismiss()
    }

    private var hexIsValid: Bool {
        PaletteColor(hexString: hexDigits, dominance: 0) != nil
    }

    private func updateFromTypedHex(_ value: String) {
        var candidate = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if candidate.hasPrefix("#") {
            candidate.removeFirst()
        } else if candidate.hasPrefix("0X") {
            candidate.removeFirst(2)
        }
        let filtered = String(candidate.filter(\.isHexDigit).prefix(6))
        if filtered != value {
            hexDigits = filtered
            return
        }

        guard let swatch = PaletteColor(hexString: filtered, dominance: 0) else {
            if filtered.count == 6 { hexError = "Enter a valid hex color." }
            return
        }
        customColor = swatch.color
        hexError = nil
    }

    private func applyPastedHex(_ value: String) {
        guard let swatch = PaletteColor(hexString: value, dominance: 0) else {
            hexError = "That clipboard value is not a six-digit hex color."
            return
        }
        hexDigits = String(swatch.hex.dropFirst())
        customColor = swatch.color
        hexError = nil
    }

    private func validateHex() {
        hexError = hexIsValid ? nil : "Enter all six hex digits."
    }

    private func loadSavedColors() async {
        guard clerk.user != nil else {
            loadState = .signedOut
            return
        }
        loadState = .loading
        switch await SavedPaletteService.listColors() {
        case .success(let colors):
            savedColors = colors
            loadState = .loaded
        case .failure(.notSignedIn):
            loadState = .signedOut
        case .failure(let error):
            loadState = .failed(error.message)
        }
    }
}

#Preview {
    AddColorView(
        insertionIndex: 2,
        initialSwatch: PaletteColor(hex: 0x88858A, dominance: 0)
    )
        .environment(PaletteStore())
        .environment(Clerk.preview())
}
