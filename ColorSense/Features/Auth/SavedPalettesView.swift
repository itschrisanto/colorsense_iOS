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
    @State private var toast: String?

    private enum LoadState: Equatable {
        case loading
        case loaded
        case failed(SavedPaletteService.SaveError)
    }

    var body: some View {
        if isEmbedded {
            // No navigation chrome at all when embedded. Previously this still applied an empty
            // navigationTitle and toolbar, so switching Library tabs made the parent's bar change
            // identity mid-transition — the title blanked out and came back.
            content
        } else {
            NavigationStack {
                content
                    .navigationTitle("Saved palettes")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { dismiss() }
                        }
                    }
            }
        }
    }

    private var content: some View {
        Group {
                switch state {
                case .loading:
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failed(let error):
                    errorState(error)
                case .loaded:
                    palettes.isEmpty ? nil : list
                    if palettes.isEmpty { emptyState }
                }
            }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(BrandFont.ui(14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay { Capsule().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5) }
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
        LaumaNotice(
            pose: .curious,
            title: "No saved palettes yet",
            message: "Save a palette from the share menu and it appears here and on colorsense.online."
        )
    }

    private func errorState(_ error: SavedPaletteService.SaveError) -> some View {
        LaumaNotice(pose: .sad, title: "That did not load", message: error.message) {
            // Only offered where it could actually work — see SaveError.isRetryable.
            if error.isRetryable {
                Button("Try again") { Task { await load() } }
            }
        }
    }

    private func load() async {
        switch await SavedPaletteService.list() {
        case .success(let result):
            palettes = result
            state = .loaded
        case .failure(let error):
            state = .failed(error)
        }
    }

    private func delete(at offsets: IndexSet) async {
        let targets = offsets.map { palettes[$0] }
        // Optimistic: the row disappears immediately, and a failed delete restores it on reload.
        palettes.remove(atOffsets: offsets)
        for target in targets {
            if case .failure(let error) = await SavedPaletteService.delete(id: target.id) {
                await load()
                show(error.deleteMessage)
                return
            }
        }
    }

    private func show(_ message: String) {
        withAnimation(.snappy) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.snappy) { if toast == message { toast = nil } }
        }
    }
}
