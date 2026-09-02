import Foundation

/// The developer- and designer-facing export formats. All are Pro-only; free and signed-out
/// users get the image export and the two clipboard copies.
///
/// Every case writes a real file rather than clipboard text, because these are meant to be
/// dropped into a project or opened by another app.
enum PaletteFileFormat: String, CaseIterable, Identifiable {
    case procreate
    case pdf
    case tailwind
    case ase
    case code
    case embed
    case svg

    var id: String { rawValue }

    var title: String {
        switch self {
        case .procreate: return "Procreate"
        case .pdf: return "PDF"
        case .tailwind: return "Tailwind"
        case .ase: return "ASE"
        case .code: return "Code"
        case .embed: return "Embed"
        case .svg: return "SVG"
        }
    }

    var summary: String {
        switch self {
        case .procreate: return "Swatches for iPad"
        case .pdf: return "Printable sheet"
        case .tailwind: return "tailwind.config.js"
        case .ase: return "Adobe swatch library"
        case .code: return "CSS, SCSS and JSON"
        case .embed: return "HTML snippet"
        case .svg: return "Vector swatches"
        }
    }

    var systemImage: String {
        switch self {
        case .procreate: return "paintbrush.pointed"
        case .pdf: return "doc.richtext"
        case .tailwind: return "wind"
        case .ase: return "swatchpalette"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .embed: return "chevron.left.slash.chevron.right"
        case .svg: return "bezier.path"
        }
    }

    var fileExtension: String {
        switch self {
        case .procreate: return "swatches"
        case .pdf: return "pdf"
        case .tailwind: return "js"
        case .ase: return "ase"
        case .code: return "txt"
        case .embed: return "html"
        case .svg: return "svg"
        }
    }
}
