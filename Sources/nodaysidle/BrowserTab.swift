import Foundation

struct BrowserTab: Identifiable, Equatable {
    let id: UUID
    var title: String
    var url: URL?
    var isHome: Bool
    var isLoading: Bool
    var canGoBack: Bool
    var canGoForward: Bool
    var estimatedProgress: Double
    /// Set when the last navigation failed; cleared on the next load attempt.
    var navigationError: String?

    static func home() -> BrowserTab {
        BrowserTab(
            id: UUID(),
            title: "New Tab",
            url: nil,
            isHome: true,
            isLoading: false,
            canGoBack: false,
            canGoForward: false,
            estimatedProgress: 0.0,
            navigationError: nil
        )
    }
}
