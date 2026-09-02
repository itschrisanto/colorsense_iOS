import SwiftUI

/// The signed-in user's saved palettes — the same library the web app shows under Account.
/// Tapping one loads it as the app's current palette, which is the point of syncing them at all:
/// a palette saved from the web should be one tap from being worked on here.
struct SavedPalettesView: View {
    /// When embedded in `LibraryView` the parent already provides the navigation bar and Done
    /// button, so this drops its own rather than nesting two.
    var isEmbedded = false

    @Environment(PaletteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var palettes: [SavedPaletteService.SavedPalette] = []
    @State private var state: LoadState = .loading

    private enum LoadState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    var body: some View {
        if isEmbedded {
            content
        } else {
            NavigationStack { content }
        }
    }

    private var content: some View {
        Group {
                switch state {
                case .loading:
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failed(let message):
                    message.isEmpty ? nil : errorState(message)
                case .loaded:
                    palettes.isEmpty ? nil : list
                    if palettes.isEmpty { emptyState }
                }
            }
        .navigationTitle(isEmbedded ? "" : "Saved palettes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isEmbedded {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    private var list: some View {
        List {
            ForEach(palettes) { saved in
                Button {
                    store.replace(with: saved.asExtractedPalette)
                    dismiss()
                } label: {
                    row(saved)
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                Task { await delete(at: offsets) }
            }
        }
        .listStyle(.plain)
        .refreshable { await load() }
    }

    private func row(_ saved: SavedPaletteService.SavedPalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                ForEach(saved.paletteColors) { swatch in
                    swatch.color.frame(height: 52)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
            }

            Text(saved.name)
                .font(BrandFont.ui(15, weight: .medium))
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bookmark")
                .font(.system(size: 34))
                .foregroundStyle(BrandColor.coral)
            Text("No saved palettes yet")
                .font(BrandFont.ui(17, weight: .bold))
            Text("Save a palette from the share menu and it appears here and on colorsense.online.")
                .font(BrandFont.ui(14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(BrandFont.ui(15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try again") { Task { await load() } }
                .font(BrandFont.ui(15, weight: .medium))
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() async {
        switch await SavedPaletteService.list() {
        case .success(let result):
            palettes = result
            state = .loaded
        case .failure(let error):
            state = .failed(error.message)
        }
    }

    private func delete(at offsets: IndexSet) async {
        let targets = offsets.map { palettes[$0] }
        // Optimistic: the row disappears immediately, and a failed delete restores it on reload.
        palettes.remove(atOffsets: offsets)
        for target in targets where await SavedPaletteService.delete(id: target.id).isFailure {
            await load()
            return
        }
    }
}

private extension Result {
    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}
