import Foundation

// MARK: - Adobe Swatch Exchange

/// Writes an `.ase` swatch library, readable by Photoshop, Illustrator and InDesign.
///
/// The format is small and fully documented, so it is written by hand rather than pulling in a
/// dependency. Layout, all big-endian:
///
///     "ASEF"  u32 version(1.0)  u32 blockCount
///     per colour block:
///       u16 type(0x0001 = colour entry)   u32 blockLength
///       u16 nameLength (UTF-16 units, including the trailing NUL)
///       UTF-16BE name, NUL-terminated
///       "RGB "  f32 r  f32 g  f32 b   u16 colourType(0 = global)
enum ASEWriter {
    static func data(for palette: ExtractedPalette) -> Data {
        var output = Data()
        output.append(contentsOf: Array("ASEF".utf8))
        output.appendBigEndian(UInt16(1))               // version major
        output.appendBigEndian(UInt16(0))               // version minor
        output.appendBigEndian(UInt32(palette.colors.count))

        for swatch in palette.colors {
            var block = Data()

            // Names are UTF-16 big-endian and NUL-terminated; the count includes that NUL.
            let scalars = Array(swatch.name.utf16)
            block.appendBigEndian(UInt16(scalars.count + 1))
            for unit in scalars { block.appendBigEndian(unit) }
            block.appendBigEndian(UInt16(0))

            block.append(contentsOf: Array("RGB ".utf8))
            block.appendBigEndian(Float(swatch.red))
            block.appendBigEndian(Float(swatch.green))
            block.appendBigEndian(Float(swatch.blue))
            block.appendBigEndian(UInt16(0))            // 0 = global colour

            output.appendBigEndian(UInt16(1))           // block type: colour entry
            output.appendBigEndian(UInt32(block.count))
            output.append(block)
        }

        return output
    }
}

// MARK: - Procreate

/// Writes a `.swatches` file for Procreate.
///
/// The format is a ZIP archive containing a single `Swatches.json`. Procreate accepts stored
/// (uncompressed) entries, so the archive is built by hand — Foundation ships no ZIP writer, and
/// a stored archive is a short, well-specified structure.
///
/// Colours are HSV with components in 0...1, and Procreate caps a palette at 30 swatches.
enum ProcreateSwatchesWriter {
    static func data(for palette: ExtractedPalette) -> Data? {
        guard let json = swatchesJSON(for: palette) else { return nil }
        return zipArchive(fileName: "Swatches.json", contents: json)
    }

    private static func swatchesJSON(for palette: ExtractedPalette) -> Data? {
        let swatches: [[String: Any]] = palette.colors.prefix(30).map { swatch in
            let hsb = hsv(red: swatch.red, green: swatch.green, blue: swatch.blue)
            return [
                "hue": hsb.hue,
                "saturation": hsb.saturation,
                "brightness": hsb.brightness,
                "alpha": 1,
                "colorSpace": 0,
            ]
        }
        let document: [[String: Any]] = [[
            "name": "ColorSense",
            "swatches": swatches,
        ]]
        return try? JSONSerialization.data(withJSONObject: document)
    }

    private static func hsv(
        red: Double, green: Double, blue: Double
    ) -> (hue: Double, saturation: Double, brightness: Double) {
        let hsl = ColorMath.hsl(fromRed: red, green: green, blue: blue)
        // Procreate wants HSV, and ColorMath produces HSL, so convert rather than pass HSL
        // through — the two agree on hue but not on saturation or value.
        let value = hsl.lightness + hsl.saturation * min(hsl.lightness, 1 - hsl.lightness)
        let saturation = value == 0 ? 0 : 2 * (1 - hsl.lightness / value)
        return (hsl.hue / 360, saturation, value)
    }

    /// A minimal ZIP with one stored entry: local header, data, central directory, end record.
    private static func zipArchive(fileName: String, contents: Data) -> Data {
        let nameBytes = Array(fileName.utf8)
        let crc = crc32(contents)
        var archive = Data()

        // Version needed and the general-purpose flag are two separate 16-bit fields. Collapsing
        // them into one left every following field 2 bytes short, which produced an archive that
        // looked plausible to `file` but failed `unzip -t`.
        func appendCommonFields(to data: inout Data) {
            data.appendLittleEndian(UInt16(20))                   // version needed to extract
            data.appendLittleEndian(UInt16(0))                    // general purpose bit flag
            data.appendLittleEndian(UInt16(0))                    // method 0 = stored
            data.appendLittleEndian(UInt16(0))                    // mod time
            data.appendLittleEndian(UInt16(0))                    // mod date
            data.appendLittleEndian(crc)
            data.appendLittleEndian(UInt32(contents.count))       // compressed size
            data.appendLittleEndian(UInt32(contents.count))       // uncompressed size
            data.appendLittleEndian(UInt16(nameBytes.count))
        }

        let localHeaderOffset = UInt32(archive.count)
        archive.appendLittleEndian(UInt32(0x0403_4B50))           // local file header
        appendCommonFields(to: &archive)
        archive.appendLittleEndian(UInt16(0))                     // extra field length
        archive.append(contentsOf: nameBytes)
        archive.append(contents)

        let centralDirectoryOffset = UInt32(archive.count)
        archive.appendLittleEndian(UInt32(0x0201_4B50))           // central directory header
        archive.appendLittleEndian(UInt16(0))                     // version made by
        appendCommonFields(to: &archive)
        archive.appendLittleEndian(UInt16(0))                     // extra field length
        archive.appendLittleEndian(UInt16(0))                     // comment length
        archive.appendLittleEndian(UInt16(0))                     // disk number
        archive.appendLittleEndian(UInt16(0))                     // internal attributes
        archive.appendLittleEndian(UInt32(0))                     // external attributes
        archive.appendLittleEndian(localHeaderOffset)
        archive.append(contentsOf: nameBytes)

        let centralDirectorySize = UInt32(archive.count) - centralDirectoryOffset
        archive.appendLittleEndian(UInt32(0x0605_4B50))           // end of central directory
        archive.appendLittleEndian(UInt16(0))                     // this disk
        archive.appendLittleEndian(UInt16(0))                     // disk with central directory
        archive.appendLittleEndian(UInt16(1))                     // entries on this disk
        archive.appendLittleEndian(UInt16(1))                     // entries total
        archive.appendLittleEndian(centralDirectorySize)
        archive.appendLittleEndian(centralDirectoryOffset)
        archive.appendLittleEndian(UInt16(0))                     // comment length

        return archive
    }

    /// Standard CRC-32 (IEEE 802.3), which ZIP requires per entry.
    private static func crc32(_ data: Data) -> UInt32 {
        var table = [UInt32](repeating: 0, count: 256)
        for index in 0..<256 {
            var value = UInt32(index)
            for _ in 0..<8 {
                value = (value & 1) == 1 ? (0xEDB8_8320 ^ (value >> 1)) : (value >> 1)
            }
            table[index] = value
        }
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private extension Data {
    mutating func appendBigEndian(_ value: UInt16) {
        append(contentsOf: [UInt8(value >> 8), UInt8(value & 0xFF)])
    }

    mutating func appendBigEndian(_ value: UInt32) {
        append(contentsOf: (0..<4).reversed().map { UInt8((value >> ($0 * 8)) & 0xFF) })
    }

    mutating func appendBigEndian(_ value: Float) {
        appendBigEndian(value.bitPattern)
    }

    mutating func appendLittleEndian(_ value: UInt16) {
        append(contentsOf: [UInt8(value & 0xFF), UInt8(value >> 8)])
    }

    mutating func appendLittleEndian(_ value: UInt32) {
        append(contentsOf: (0..<4).map { UInt8((value >> ($0 * 8)) & 0xFF) })
    }
}
