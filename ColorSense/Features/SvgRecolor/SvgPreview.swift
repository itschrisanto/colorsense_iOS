import SwiftUI
import WebKit

/// Renders an SVG.
///
/// iOS cannot draw SVG. There is no `UIImage(svg:)`, `Image` does not read it, and the alternatives
/// to a web view are adding a third-party renderer or writing one. So this is a `WKWebView`, and it
/// is worth being precise that this does **not** reopen the "fresh native SwiftUI, not a WebView
/// wrapper" decision in CLAUDE.md: that ruled out proxying the app's own screens to the website.
/// This draws a local string in a file format the platform cannot otherwise display.
///
/// Two things make hosting an untrusted document here safe, and both must stay:
///
/// - **JavaScript is off**, through `allowsContentJavaScript = false`. Script in the file cannot
///   run at all, which is the actual defence. `SvgRecolor.sanitized` is belt to this braces.
/// - **Nothing loads from the network.** The SVG is handed over as a string with `baseURL: nil`,
///   so relative references resolve nowhere, and the navigation delegate refuses anything that is
///   not the initial load. A file that tries to phone home cannot.
struct SvgPreview: UIViewRepresentable {
    let svg: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let pageConfig = WKWebpagePreferences()
        pageConfig.allowsContentJavaScript = false

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = pageConfig
        // A non-persistent store, so a document that manages to write anything leaves nothing on
        // disk between openings.
        config.websiteDataStore = .nonPersistent()

        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.scrollView.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.lastRendered != svg else { return }
        context.coordinator.lastRendered = svg
        view.loadHTMLString(document(for: svg), baseURL: nil)
    }

    /// The SVG centred and scaled to fit, on nothing. The checkerboard behind it is drawn in
    /// SwiftUI rather than here, so transparency reads as transparency.
    private func document(for svg: String) -> String {
        """
        <!doctype html><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>
          html,body{margin:0;height:100%;background:transparent}
          body{display:flex;align-items:center;justify-content:center}
          svg{max-width:100%;max-height:100%;height:auto;width:auto}
        </style>
        \(SvgRecolor.sanitized(svg))
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastRendered: String?

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Only the `loadHTMLString` call itself is allowed. Every other navigation, including
            // anything the document initiates, is refused.
            decisionHandler(navigationAction.request.url?.scheme == "about" ? .allow : .cancel)
        }
    }
}
