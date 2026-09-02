import Testing
import Foundation
@testable import ColorSense

/// These two formats are written byte by byte, so they get structural tests rather than
/// "did it produce something" — an earlier ZIP bug passed `file(1)` and a green build while
/// still failing `unzip -t`.
struct ASEWriterTests {
    @Test func startsWithTheASEFHeaderAndBlockCount() {
        let data = ASEWriter.data(for: .sample)
        #expect(Array(data.prefix(4)) == Array("ASEF".utf8))
        // version 1.0
        #expect(Array(data[4..<8]) == [0, 1, 0, 0])
        let blockCount = data[8..<12].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        #expect(blockCount == UInt32(ExtractedPalette.sample.colors.count))
    }

    @Test func firstBlockDeclaresItsOwnLength() {
        let data = ASEWriter.data(for: .sample)
        let blockType = (UInt16(data[12]) << 8) | UInt16(data[13])
        #expect(blockType == 1) // colour entry
        let blockLength = data[14..<18].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        // The declared length must actually fit inside the file.
        #expect(18 + Int(blockLength) <= data.count)
    }

    @Test func namesAreUTF16BigEndianAndNulTerminated() {
        let single = ExtractedPalette(
            colors: [PaletteColor(hex: 0x2A2C32, dominance: 1)], createdAt: Date()
        )
        let data = ASEWriter.data(for: single)
        let nameLength = Int((UInt16(data[18]) << 8) | UInt16(data[19]))
        let expected = single.colors[0].name
        #expect(nameLength == expected.utf16.count + 1)

        let nameBytes = Array(data[20..<(20 + nameLength * 2)])
        let units = stride(from: 0, to: nameBytes.count, by: 2).map {
            (UInt16(nameBytes[$0]) << 8) | UInt16(nameBytes[$0 + 1])
        }
        #expect(units.last == 0)
        #expect(String(utf16CodeUnits: Array(units.dropLast()), count: units.count - 1) == expected)
    }
}

struct ProcreateSwatchesTests {
    @Test func isAWellFormedZipArchive() throws {
        let data = try #require(ProcreateSwatchesWriter.data(for: .sample))
        // Local file header, central directory and end-of-central-directory signatures.
        #expect(Array(data.prefix(4)) == [0x50, 0x4B, 0x03, 0x04])
        #expect(data.range(of: Data([0x50, 0x4B, 0x01, 0x02])) != nil)
        #expect(data.range(of: Data([0x50, 0x4B, 0x05, 0x06])) != nil)
        #expect(data.range(of: Data("Swatches.json".utf8)) != nil)
    }

    /// The stored entry is uncompressed, so the JSON sits verbatim in the archive and can be
    /// parsed straight out of it without a ZIP reader.
    @Test func carriesHSVSwatchesProcreateCanRead() throws {
        let data = try #require(ProcreateSwatchesWriter.data(for: .sample))
        let start = try #require(data.range(of: Data("[{".utf8)))
        let end = try #require(data.range(of: Data("}]".utf8), options: .backwards))
        let json = data[start.lowerBound..<end.upperBound]

        let parsed = try JSONSerialization.jsonObject(with: json) as? [[String: Any]]
        let document = try #require(parsed?.first)
        #expect(document["name"] as? String == "ColorSense")

        let swatches = try #require(document["swatches"] as? [[String: Any]])
        #expect(swatches.count == ExtractedPalette.sample.colors.count)

        for swatch in swatches {
            for key in ["hue", "saturation", "brightness"] {
                let value = try #require(swatch[key] as? Double)
                #expect(value >= 0 && value <= 1, "\(key) out of range: \(value)")
            }
            #expect(swatch["alpha"] as? Int == 1)
        }
    }

    /// Procreate refuses palettes longer than 30 swatches.
    @Test func clampsToProcreatesThirtySwatchCeiling() throws {
        let many = ExtractedPalette(
            colors: (0..<40).map { PaletteColor(hex: UInt32($0 * 5000), dominance: 0.025) },
            createdAt: Date()
        )
        let data = try #require(ProcreateSwatchesWriter.data(for: many))
        let start = try #require(data.range(of: Data("[{".utf8)))
        let end = try #require(data.range(of: Data("}]".utf8), options: .backwards))
        let parsed = try JSONSerialization.jsonObject(
            with: data[start.lowerBound..<end.upperBound]
        ) as? [[String: Any]]
        let swatches = try #require(parsed?.first?["swatches"] as? [[String: Any]])
        #expect(swatches.count == 30)
    }
}

@MainActor
struct PaletteFileExporterTests {
    @Test(arguments: PaletteFileFormat.allCases)
    func everyFormatWritesANonEmptyFileWithItsExtension(format: PaletteFileFormat) throws {
        let url = try #require(PaletteFileExporter.file(format, for: .sample))
        #expect(url.pathExtension == format.fileExtension)
        let size = try Data(contentsOf: url).count
        #expect(size > 0, "\(format.rawValue) wrote an empty file")
    }

    @Test func textFormatsNameEveryColour() throws {
        let url = try #require(PaletteFileExporter.file(.tailwind, for: .sample))
        let contents = try String(contentsOf: url, encoding: .utf8)
        for swatch in ExtractedPalette.sample.colors {
            #expect(contents.contains(swatch.hex.lowercased()))
        }
    }

    /// Two swatches can share a nearest-colour name; without the index fallback they would
    /// collide into one key and silently drop a colour.
    @Test func duplicateNamesDoNotCollapseIntoOneKey() throws {
        let duplicated = ExtractedPalette(
            colors: [
                PaletteColor(hex: 0x2A2C32, dominance: 0.5),
                PaletteColor(hex: 0x2A2C32, dominance: 0.5),
            ],
            createdAt: Date()
        )
        let url = try #require(PaletteFileExporter.file(.code, for: duplicated))
        let contents = try String(contentsOf: url, encoding: .utf8)
        let cssLines = contents.split(separator: "\n").filter { $0.hasPrefix("  --") }
        #expect(Set(cssLines).count == cssLines.count, "duplicate CSS variable names: \(cssLines)")
    }
}
