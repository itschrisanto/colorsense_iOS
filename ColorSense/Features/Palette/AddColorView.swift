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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var customColor: Color
    /// Whether what is currently typed in the hex field is a colour. Owned by `CustomColorEditor`,
    /// kept here because the Add button is gated on it.
    @State private var hexIsValid = true
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

    /// Whether the reader can go past the free five. Checked here rather than in `PaletteStore`,
    /// because the store has no idea what anyone is paying and should not learn.
    var isPro = false

    init(insertionIndex: Int, initialSwatch: PaletteColor, isPro: Bool = false) {
        self.insertionIndex = insertionIndex
        self.isPro = isPro
        _customColor = State(initialValue: initialSwatch.color)
    }

    /// A free palette stops at five. The sixth through eighth are Pro.
    private var isAtFreeLimit: Bool {
        !isPro && store.palette.colors.count >= PaletteStore.freeColorCount
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if isAtFreeLimit {
                        limitNotice
                    } else {
                        customColorSection
                        savedColorSection
                    }
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
            let swatch = PaletteColor(color: customColor)
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
                        .brandMono(13)
                        .foregroundStyle(.secondary)
                }

                CustomColorEditor(color: $customColor, isValid: $hexIsValid)

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
                    .brandMono(11)
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

    /// Named, priced and inert. No route to buy, because there is no in-app purchase yet and
    /// guideline 3.1.1 forbids pointing at an outside one, the same as every other Pro wall here.
    private var limitNotice: some View {
        LaumaNotice(
            pose: .unsure,
            title: "Five colors on the free plan",
            message: "A palette can hold up to eight. The sixth, seventh and eighth come with Pro. Remove a color to add a different one."
        )
    }

    private func add(_ swatch: PaletteColor) {
        guard !isAtFreeLimit else { return }
        // The editor reports this, and also shows the reason inline, so there is nothing to
        // re-validate here: refusing quietly is enough.
        guard hexIsValid else { return }
        var inserted = false
        withAnimation(PaletteMotion.structural(reduceMotion: reduceMotion)) {
            inserted = store.insert(swatch, at: insertionIndex)
        }
        guard inserted else { return }
        dismiss()
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
