import SwiftUI
import Testing
@testable import ColorSense

@MainActor
@Suite("SVG and image exports", .serialized)
struct SvgExportTests {
    private let fixture = ##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100"><rect width="100" height="100" fill="#ff0000"/><rect x="100" width="100" height="100" fill="#0000ff"/></svg>"##

    @Test func pngContainsArtworkNotABlankWebView() async throws {
        let renderer = SvgPNGRenderer(document: .init(svg: fixture, name: "test"))
        let data = try await renderer.pngData()
        let image = try #require(UIImage(data: data)?.cgImage)
        #expect(image.width == 2048)
        #expect(image.height == 1024)
        let pixels = rgba(image, width: 2, height: 1)
        #expect(pixels[0] > 240 && pixels[1] < 15 && pixels[2] < 15 && pixels[3] > 240, "RGBA samples: \(pixels)")
        #expect(pixels[4] < 15 && pixels[5] < 15 && pixels[6] > 240 && pixels[7] > 240, "RGBA samples: \(pixels)")
    }

    @Test func allVisualizerScenesProduceNonemptyPNGImages() async throws {
        for scene in VisualizerScene.allCases {
            let svg = VisualizerSVG.document(scene, palette: ExtractedPalette.sample.colors.map(\.hex))
            let renderer = SvgPNGRenderer(document: .init(svg: svg, name: scene.title))
            let data = try await renderer.pngData()
            let image = try #require(UIImage(data: data)?.cgImage)
            #expect(image.width == 2048)
            let pixels = rgba(image, width: 16, height: 16)
            #expect(Set(stride(from: 0, to: pixels.count, by: 4).map { Array(pixels[$0..<$0 + 4]) }).count > 1)
        }
    }

    @Test func invalidSVGReportsAnError() async {
        let renderer = SvgPNGRenderer(document: .init(svg: "not an SVG", name: "invalid"))
        await #expect(throws: SvgExportError.self) { try await renderer.pngData() }
    }

    @Test func exportFilesAreIsolatedAndWriteFailuresAreNotSwallowed() throws {
        let directory = URL.temporaryDirectory.appendingPathComponent("svg-export-test-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = SvgExportDocument(svg: fixture, name: "same-name")
        let second = SvgExportDocument(svg: fixture.replacingOccurrences(of: "#ff0000", with: "#00ff00"), name: "same-name")
        let firstURL = try first.writeSVG(directory: directory)
        let secondURL = try second.writeSVG(directory: directory)
        #expect(firstURL != secondURL)
        #expect(try String(contentsOf: firstURL, encoding: .utf8) == fixture)
        #expect(throws: (any Error).self) { try first.writeSVG(directory: firstURL) }
    }

    @Test func rendererDisablesScriptsAndRemoteSubresources() {
        let renderer = SvgPNGRenderer(document: .init(svg: fixture, name: "safe"))
        #expect(!renderer.webView.configuration.defaultWebpagePreferences.allowsContentJavaScript)
        #expect(!renderer.webView.configuration.websiteDataStore.isPersistent)
        let html = SvgPNGRenderer.html(for: fixture)
        #expect(html.contains("default-src 'none'"))
        #expect(html.contains("img-src data:"))
    }

    private func rgba(_ image: CGImage, width: Int, height: Int) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return pixels
    }
}
