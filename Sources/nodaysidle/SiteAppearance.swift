import AppKit
import WebKit

/// Keeps WebKit's loading surface aligned with the app chrome while leaving
/// each website responsible for its own light/dark appearance.
@MainActor
enum SiteAppearance {
    private static let voidBackground = NSColor(red: 0.082, green: 0.082, blue: 0.088, alpha: 1)

    static func makeConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        return config
    }

    static func apply(to webView: WKWebView) {
        webView.underPageBackgroundColor = voidBackground
    }
}
