import SwiftUI

/// The Library tool: the user's own saved palettes alongside the public curated library.
///
/// Both tabs do the same thing on tap — load that palette into the workspace — which is why they
/// live behind one screen rather than two separate tools. Explore reads the same approved
/// palettes the web's Explore shows, and needs no sign-in.
struct LibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .saved

    enum Tab: String, CaseIterable, Identifiable {
        case saved, explore
        var id: String { rawValue }
        var title: String {
            switch self {
            case .saved: return "Saved"
            case .explore: return "Explore"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch tab {
                case .saved: SavedPalettesContent()
                case .explore: ExploreContent()
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            // Without an explicit surface the bar is translucent glass and the list scrolls
            // under it, smearing swatch colours through the segmented control. The palette
            // screen needed the same treatment for the same reason.
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Library section", selection: $tab) {
                        ForEach(Tab.allCases) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                BackToPalette { dismiss() }
            }
        }
    }
}

/// The public curated library. Paginated because the endpoint returns 30 at a time and the
/// catalogue is far larger than one page.
private struct ExploreContent: View {
    @Environment(PaletteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var palettes: [SavedPaletteService.ExplorePalette] = []
    @State private var page = 1
    @State private var hasMore = false
    @State private var isLoading = false
    @State private var loadError: SavedPaletteService.SaveError?
    @State private var query = ""

    var body: some View {
        List {
            ForEach(palettes) { palette in
                Button {
                    store.replace(with: palette.asExtractedPalette)
                    dismiss()
                } label: {
                    row(palette)
                }
                .buttonStyle(.plain)
            }

            if hasMore && loadError == nil {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .task { await load(nextPage: true) }
            }

            if let loadError {
                VStack(spacing: 10) {
                    Text(loadError.message)
                        .font(BrandFont.ui(14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    // Gated the same way the other screens are — see SaveError.isRetryable.
                    if loadError.isRetryable {
                        Button("Try again") { Task { await load(nextPage: false) } }
                            .font(BrandFont.ui(15, weight: .medium))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .searchable(text: $query, prompt: "Search palettes")
        .onSubmit(of: .search) { Task { await load(nextPage: false) } }
        .overlay {
            if palettes.isEmpty && isLoading { ProgressView() }
            if palettes.isEmpty && !isLoading && loadError == nil && !query.isEmpty {
                LaumaNotice(
                    pose: .unsure,
                    title: "Nothing matches that",
                    message: "No palettes match “\(query)”. Try a shorter word, or a color name."
                )
            }
        }
        .task { if palettes.isEmpty { await load(nextPage: false) } }
    }

    private func row(_ palette: SavedPaletteService.ExplorePalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                ForEach(palette.paletteColors) { swatch in
                    swatch.color.frame(height: 52)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
            }
            HStack(spacing: 6) {
                Text(palette.name)
                    .font(BrandFont.ui(15, weight: .medium))
                Text(palette.category.capitalized)
                    .font(BrandFont.ui(11, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.primary.opacity(0.08))
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
    }

    private func load(nextPage: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil
        let target = nextPage ? page + 1 : 1

        switch await SavedPaletteService.explore(page: target, query: query) {
        case .success(let result):
            // Replacing on a fresh load matters: a new search must not append to the old results.
            palettes = nextPage ? palettes + result.palettes : result.palettes
            page = result.page
            hasMore = result.hasMore
        case .failure(let error):
            loadError = error
            hasMore = false
        }
        isLoading = false
    }
}

/// Wraps the existing saved-palettes list so both tabs sit under one navigation bar rather than
/// each bringing its own.
private struct SavedPalettesContent: View {
    var body: some View {
        SavedPalettesView(isEmbedded: true)
    }
}
