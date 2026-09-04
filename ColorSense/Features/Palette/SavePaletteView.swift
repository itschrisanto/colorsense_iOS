import SwiftUI

/// Names a palette before it goes to the user's account. Previously Save posted immediately with
/// the server's `Palette of <date>` fallback, which made a library of saved palettes impossible
/// to tell apart. Mirrors `SaveColorView` so naming a palette and naming a color feel the same.
struct SavePaletteView: View {
    let palette: ExtractedPalette
    var isPro = false
    let onSaved: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var nameIsFocused: Bool
    /// How full the account is, read once when the screen opens. Nil means not known yet or the
    /// lookup failed, and an unknown count never blocks a save: refusing to save somebody's work
    /// because a *count* would not load is a worse failure than letting the server decide.
    @State private var savedCount: Int?

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isAtLimit: Bool {
        guard !isPro, let savedCount else { return false }
        return savedCount >= SavedPaletteService.Allowance.palettes
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                preview

                TextField("Palette name", text: $name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($nameIsFocused)
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .onSubmit { save() }

                if isAtLimit {
                    LaumaNotice(
                        pose: .unsure,
                        title: "Your library is full",
                        message: "A free account holds \(SavedPaletteService.Allowance.palettes) saved palettes. Delete one to make room, or Pro removes the limit."
                    )
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(BrandFont.ui(13))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    save()
                } label: {
                    Group {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Label("Save to my account", systemImage: "bookmark")
                        }
                    }
                }
                .buttonStyle(.primaryAction)
                .disabled(isSaving || trimmedName.isEmpty || isAtLimit)
                .opacity(trimmedName.isEmpty ? 0.55 : 1)

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Save palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                nameIsFocused = true
                // Only a free account can be full, so a Pro reader is never made to wait on a
                // count that cannot stop them.
                if !isPro { savedCount = await SavedPaletteService.savedPaletteCount() }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                ForEach(palette.colors) { swatch in
                    swatch.color.frame(height: 56)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
            }
            Text("Give this palette a name you will recognize later. It appears here and in your web Library.")
                .font(BrandFont.ui(13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func save() {
        guard !isAtLimit else { return }
        guard !trimmedName.isEmpty, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        Task {
            switch await SavedPaletteService.save(palette, name: trimmedName) {
            case .success:
                AnalyticsService.capture(.paletteSaved, ["colors": palette.colors.count])
                onSaved(trimmedName)
                dismiss()
            case .failure(let error):
                errorMessage = error.message
                isSaving = false
            }
        }
    }
}
