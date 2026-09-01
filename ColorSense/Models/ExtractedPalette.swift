import Foundation

struct ExtractedPalette: Identifiable {
    let id = UUID()
    let colors: [PaletteColor]
    let createdAt: Date
}
