import SwiftUI
import WebKit
import CoreTransferable
import UniformTypeIdentifiers

/// An immutable export, captured when Export is tapped, not rewritten during body evaluation.
struct SvgExportDocument: Identifiable {
    let id = UUID()
    let svg: String
    let name: String

    var aspectRatio: Double {
        let ratio = SvgRecolor.aspectRatio(of: svg) ?? 1
        return ratio.isFinite && ratio > 0 ? ratio : 1
    }

    func size(longEdge: CGFloat) -> CGSize {
        let ratio = aspectRatio
        return ratio >= 1
            ? CGSize(width: longEdge, height: max(1, longEdge / ratio))
            : CGSize(width: max(1, longEdge * ratio), height: longEdge)
    }

    func writeSVG(directory: URL = FileManager.default.temporaryDirectory) throws -> URL {
        let folder = directory.appendingPathComponent("ColorSense-export-\(id.uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let safeName = String(name.map { "/\\:".contains($0) ? "-" : $0 }.prefix(120))
        let file = folder.appendingPathComponent(safeName.isEmpty ? "artwork" : safeName).appendingPathExtension("svg")
        try SvgRecolor.sanitized(svg).write(to: file, atomically: true, encoding: .utf8)
        return file
    }
}

struct SvgPNGImage: Transferable {
    let data: Data
    let name: String
    let preview: Image

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
            .suggestedFileName { "\($0.name).png" }
    }
}

enum SvgExportError: LocalizedError {
    case invalidSVG, notReady, timedOut, renderingFailed
    var errorDescription: String? {
        switch self {
        case .invalidSVG: "This file is not a valid SVG. Try opening another file."
        case .notReady: "The artwork hasn't finished loading. Please try again."
        case .timedOut: "The artwork took too long to load. Please try again."
        case .renderingFailed: "The image could not be generated. Please try again or export the SVG."
        }
    }
}

/// Render the local document through WebKit's vector PDF output, then rasterize at a bounded
/// resolution. ImageRenderer cannot render a WKWebView, and taking a screen screenshot can miss
/// its asynchronous drawing. No PDF is saved or offered as a new product feature.
@MainActor
final class SvgPNGRenderer: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    private let document: SvgExportDocument
    private var pendingLoad: CheckedContinuation<Void, Error>?
    private var timeout: Task<Void, Never>?

    init(document: SvgExportDocument) {
        self.document = document
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: CGRect(origin: .zero, size: document.size(longEdge: 300)), configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
    }

    static func html(for svg: String) -> String {
        """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:; font-src data:">
        <style>html,body{margin:0;width:100%;height:100%;overflow:hidden;background:transparent}
        body>svg{display:block;width:100%!important;height:100%!important;max-width:100%;max-height:100%}</style>
        </head><body>\(SvgRecolor.sanitized(svg))</body></html>
        """
    }

    func pngData() async throws -> Data {
        let parser = XMLParser(data: Data(SvgRecolor.sanitized(document.svg).utf8))
        parser.shouldResolveExternalEntities = false
        guard parser.parse(), document.svg.range(of: #"<svg[\s>]"#, options: [.regularExpression, .caseInsensitive]) != nil
        else { throw SvgExportError.invalidSVG }

        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                pendingLoad = continuation
                webView.loadHTMLString(Self.html(for: document.svg), baseURL: nil)
                timeout = Task { [weak self] in
                    // A cold Simulator WebKit process has taken 17 seconds to launch under the
                    // full test suite. The renderer was healthy once it started, so allow startup
                    // headroom while retaining a finite failure path for a genuinely stuck load.
                    do { try await Task.sleep(for: .seconds(30)) } catch { return }
                    self?.finish(.failure(SvgExportError.timedOut))
                }
            }
            try Task.checkCancellation()
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel() }
        }

        webView.layoutIfNeeded()
        guard webView.bounds.width > 0, webView.bounds.height > 0 else { throw SvgExportError.notReady }
        let configuration = WKPDFConfiguration()
        configuration.rect = webView.bounds
        configuration.allowTransparentBackground = true
        let pdf = try await webView.pdf(configuration: configuration)
        try Task.checkCancellation()
        guard let provider = CGDataProvider(data: pdf as CFData),
              let pdfDocument = CGPDFDocument(provider), let page = pdfDocument.page(at: 1)
        else { throw SvgExportError.renderingFailed }
        let pageBounds = page.getBoxRect(.mediaBox)
        guard pageBounds.width > 0, pageBounds.height > 0 else { throw SvgExportError.renderingFailed }
        let size = document.size(longEdge: 2048)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).pngData { context in
            let cg = context.cgContext
            cg.translateBy(x: 0, y: size.height)
            cg.scaleBy(x: 1, y: -1)
            // getDrawingTransform does not upscale a small PDF page. Explicitly scale its
            // viewport or a 300pt drawing sits tiny in the centre of a 2048px transparent PNG.
            cg.scaleBy(x: size.width / pageBounds.width, y: size.height / pageBounds.height)
            cg.translateBy(x: -pageBounds.minX, y: -pageBounds.minY)
            cg.drawPDFPage(page)
        }
    }

    func cancel() {
        webView.stopLoading()
        finish(.failure(CancellationError()))
    }

    private func finish(_ result: Result<Void, Error>) {
        timeout?.cancel()
        timeout = nil
        let continuation = pendingLoad
        pendingLoad = nil
        continuation?.resume(with: result)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finish(.success(())) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { finish(.failure(SvgExportError.renderingFailed)) }
    func webView(
        _ webView: WKWebView,
        decidePolicyFor action: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        action.request.url?.scheme == "about" ? .allow : .cancel
    }
}
