import SwiftUI

/// The signed-in user's saved colors. These are stored as named one-swatch palettes on the same
/// `/api/saved-palettes` contract the palette library uses, so they appear in the web Library too
/// — see `SavedPaletteService.SavedPalette.savedColor`.
///
/// Tapping one appends it to the current palette, mirroring what the seam picker does. It is a
/// no-op at the 8-color ceiling, which the row reflects rather than failing silently.
struct SavedColorsView: View {
    @Environment(PaletteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var colors: [SavedPaletteService.SavedColor] = []
    @State private var state: LoadState = .loading
    @State private var toast: String?

    private enum LoadState: Equatable {
        case loading
        case loaded
        case failed(SavedPaletteService.SaveError)
    }

    private var paletteIsFull: Bool {
        store.palette.colors.count >= PaletteStore.maximumColorCount
    }

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .loading:
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failed(let error):
                    errorState(error)
                case .loaded:
                    if colors.isEmpty { emptyState } else { list }
                }
            }
            .navigationTitle("Saved colors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(BrandFont.ui(14, weight: .medium))
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
    }

    private var list: some View {
        List {
            if paletteIsFull {
                Text("Your palette is full at \(PaletteStore.maximumColorCount) colors. Remove one to add another.")
                    .font(BrandFont.ui(13))
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
            }
            ForEach(colors) { saved in
                Button {
                    add(saved)
                } label: {
                    row(saved)
                }
                .buttonStyle(.plain)
                .disabled(paletteIsFull)
            }
            .onDelete { offsets in
                Task { await delete(at: offsets) }
            }
        }
        .listStyle(.plain)
        .refreshable { await load() }
    }

    private func row(_ saved: SavedPaletteService.SavedColor) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(saved.swatch.color)
                .frame(width: 52, height: 52)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(saved.name)
                    .font(BrandFont.ui(16, weight: .medium))
                Text(saved.swatch.hex)
                    .brandMono(13)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
        .opacity(paletteIsFull ? 0.45 : 1)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "paintpalette")
                .font(.system(size: 34))
                .foregroundStyle(BrandColor.coral)
            Text("No saved colors yet")
                .font(BrandFont.ui(17, weight: .bold))
            Text("Open any color and choose Save color. It appears here and in your web Library.")
                .font(BrandFont.ui(14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ error: SavedPaletteService.SaveError) -> some View {
        VStack(spacing: 12) {
            Text(error.message)
                .font(BrandFont.ui(15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            // Only offered where it could actually work — see SaveError.isRetryable.
            if error.isRetryable {
                Button("Try again") { Task { await load() } }
                    .font(BrandFont.ui(15, weight: .medium))
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func add(_ saved: SavedPaletteService.SavedColor) {
        guard store.insert(saved.swatch, at: store.palette.colors.count) else { return }
        show("\(saved.name) added to your palette")
    }

    private func load() async {
        switch await SavedPaletteService.listColors() {
        case .success(let result):
            colors = result
            state = .loaded
        case .failure(let error):
            state = .failed(error)
        }
    }

    private func delete(at offsets: IndexSet) async {
        let targets = offsets.map { colors[$0] }
        // Optimistic: the row goes immediately, and a failed delete restores it on reload.
        colors.remove(atOffsets: offsets)
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
