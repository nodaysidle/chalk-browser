import Foundation
import Observation
import WebKit

@Observable
@MainActor
final class BrowserStore {
    var tabs: [BrowserTab]
    var selectedTabID: UUID
    var searchEngine: SearchEngine = .duckduckgo {
        didSet {
            guard searchEngine != oldValue else { return }
            userDefaults.set(searchEngine.rawValue, forKey: Self.searchEngineKey)
        }
    }

    /// Tabs whose WKWebView has been created. Prevents eager creation of a
    /// WKWebView for every session-restored tab — only the selected tab (and
    /// any the user visits) gets hydrated.
    var hydratedTabIDs: Set<UUID> = []

    /// Find-in-page state.
    var findQuery = ""
    var showFindBar = false
    var findMatchIndex = 0
    var findMatchCount = 0
    var findBackwards = false
    var findTrigger = 0

    /// Tab currently being dragged in the tab bar (live reorder).
    var draggingTabID: UUID?

    /// When set, the matching home tab should auto-focus its search field once.
    var pendingNewTabFocusID: UUID?

    /// Brief zoom level feedback shown after zoom in/out/reset.
    var zoomFeedback: String?

    // MARK: - Private storage

    private static let searchEngineKey = "nodaysidle.searchEngine"
    private static let sessionKey = "nodaysidle.session"

    private let userDefaults: UserDefaults
    private(set) var webViews: [UUID: WKWebView] = [:]

    private struct ClosedTabEntry {
        let url: URL?
        let title: String
        let index: Int
    }

    /// Undo-close stack. Most recent closed tab is last.
    private var closedTabs: [ClosedTabEntry] = []
    private static let maxClosedTabs = 10

    // MARK: - Init

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let restored = Self.restoreSession(from: userDefaults)
        tabs = restored.tabs
        selectedTabID = restored.selectedID
        // The selected tab is hydrated immediately — visible on first render.
        tabSelectionOrder.append(restored.selectedID)
        hydratedTabIDs.insert(restored.selectedID)
        if let raw = userDefaults.string(forKey: Self.searchEngineKey),
           let engine = SearchEngine(rawValue: raw)
        {
            searchEngine = engine
        }
    }

    // MARK: - Computed

    var selectedTab: BrowserTab? {
        tabs.first { $0.id == selectedTabID }
    }

    var canCloseTab: Bool {
        tabs.count > 1
    }

    var canUndoCloseTab: Bool {
        !closedTabs.isEmpty
    }

    // MARK: - WebView registry

    func register(webView: WKWebView, for tabID: UUID) {
        webViews[tabID] = webView
        SiteAppearance.apply(to: webView)
    }

    func unregister(tabID: UUID) {
        webViews.removeValue(forKey: tabID)
    }

    /// Order of tab selection for LRU tab suspension memory management.
    private var tabSelectionOrder: [UUID] = []
    private static let maxHydratedTabs = 15

    // MARK: - Hydration

    func hydrateTab(_ id: UUID) {
        tabSelectionOrder.removeAll { $0 == id }
        tabSelectionOrder.append(id)
        hydratedTabIDs.insert(id)
        evictExcessHydratedTabsIfNeeded()
    }

    private func evictExcessHydratedTabsIfNeeded() {
        guard hydratedTabIDs.count > Self.maxHydratedTabs else { return }
        for candidate in tabSelectionOrder {
            if candidate != selectedTabID && hydratedTabIDs.contains(candidate) {
                unregister(tabID: candidate)
                hydratedTabIDs.remove(candidate)
                break
            }
        }
    }

    // MARK: - Tab selection

    func selectTab(_ id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        hydrateTab(id)
        selectedTabID = id
        syncNavigationState(for: id)
        dismissFind()
        persistSession()
    }

    func selectTab(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        selectTab(tabs[index].id)
    }

    func selectNextTab() {
        guard tabs.count > 1 else { return }
        if let index = tabs.firstIndex(where: { $0.id == selectedTabID }) {
            let nextIndex = (index + 1) % tabs.count
            selectTab(tabs[nextIndex].id)
        }
    }

    func selectPreviousTab() {
        guard tabs.count > 1 else { return }
        if let index = tabs.firstIndex(where: { $0.id == selectedTabID }) {
            let prevIndex = (index - 1 + tabs.count) % tabs.count
            selectTab(tabs[prevIndex].id)
        }
    }

    // MARK: - Tab lifecycle

    func newTab(opening url: URL? = nil, makeActive: Bool = true) {
        var tab = BrowserTab.home()
        if let url {
            tab.url = url
            tab.isHome = false
            tab.title = NavigationInput.title(for: url)
            tab.isLoading = true
        }
        tabs.append(tab)
        if makeActive {
            selectedTabID = tab.id
            hydrateTab(tab.id)
            pendingNewTabFocusID = tab.isHome ? tab.id : nil
        }
        persistSession()
    }

    func closeTab(_ id: UUID) {
        guard tabs.count > 1 else { return }
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let closing = tabs[index]
        let saved = ClosedTabEntry(
            url: closing.isHome ? nil : closing.url,
            title: closing.isHome ? "New Tab" : closing.title,
            index: index
        )
        unregister(tabID: id)
        hydratedTabIDs.remove(id)
        tabSelectionOrder.removeAll { $0 == id }
        tabs.remove(at: index)
        if selectedTabID == id {
            let fallbackIndex = max(0, index - 1)
            selectedTabID = tabs[fallbackIndex].id
            hydrateTab(selectedTabID)
        }
        closedTabs.append(saved)
        if closedTabs.count > Self.maxClosedTabs {
            closedTabs.removeFirst()
        }
        dismissFind()
        persistSession()
    }

    func undoCloseTab() {
        guard let saved = closedTabs.popLast() else { return }
        var tab = BrowserTab.home()
        if let url = saved.url {
            tab.url = url
            tab.isHome = false
            tab.title = saved.title
        }
        let insertIndex = min(saved.index, tabs.count)
        tabs.insert(tab, at: insertIndex)
        selectTab(tab.id)
        persistSession()
    }

    func moveTab(_ sourceID: UUID, to targetID: UUID) {
        guard let from = tabs.firstIndex(where: { $0.id == sourceID }),
              let to = tabs.firstIndex(where: { $0.id == targetID }),
              from != to
        else { return }
        let tab = tabs.remove(at: from)
        tabs.insert(tab, at: to)
        persistSession()
    }

    // MARK: - Navigation

    func navigateSelected(to input: String) {
        guard let url = NavigationInput.resolve(input, engine: searchEngine) else { return }
        navigate(tabID: selectedTabID, to: url)
    }

    func navigateSelected(to url: URL) {
        navigate(tabID: selectedTabID, to: url)
    }

    /// Navigates a specific tab. Popups/new-window requests must target the
    /// originating tab, not whichever tab happens to be selected.
    func navigate(tabID: UUID, to url: URL) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs[index].url = url
        tabs[index].isHome = false
        tabs[index].title = NavigationInput.title(for: url)
        tabs[index].isLoading = true
        tabs[index].estimatedProgress = 0.0
        tabs[index].navigationError = nil
        webViews[tabID]?.load(URLRequest(url: url))
        persistSession()
    }

    func retryNavigation(tabID: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              let url = tabs[index].url
        else { return }
        tabs[index].navigationError = nil
        tabs[index].isLoading = true
        tabs[index].estimatedProgress = 0.0
        webViews[tabID]?.load(URLRequest(url: url))
    }

    func reportNavigationError(tabID: UUID, message: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }), !tabs[index].isHome else { return }
        tabs[index].navigationError = message
        tabs[index].isLoading = false
        tabs[index].estimatedProgress = 0.0
    }

    func clearNavigationError(tabID: UUID) {
        updateTab(tabID) { $0.navigationError = nil }
    }

    func goHome() {
        guard let index = tabs.firstIndex(where: { $0.id == selectedTabID }) else { return }
        guard !tabs[index].isHome else { return }
        webViews[selectedTabID]?.stopLoading()
        tabs[index].isHome = true
        tabs[index].title = "New Tab"
        tabs[index].isLoading = false
        tabs[index].canGoBack = tabs[index].url != nil
        tabs[index].canGoForward = false
        tabs[index].estimatedProgress = 0.0
        tabs[index].navigationError = nil
        pendingNewTabFocusID = selectedTabID
        dismissFind()
        persistSession()
    }

    func goBack() {
        if let index = tabs.firstIndex(where: { $0.id == selectedTabID }), tabs[index].isHome {
            guard let url = tabs[index].url else { return }
            pendingNewTabFocusID = nil
            tabs[index].isHome = false
            tabs[index].title = Self.displayTitle(webTitle: webViews[selectedTabID]?.title, url: url)
            tabs[index].canGoBack = false
            syncNavigationState(for: selectedTabID)
            persistSession()
            return
        }
        webViews[selectedTabID]?.goBack()
    }

    func goForward() {
        webViews[selectedTabID]?.goForward()
    }

    func reload() {
        if selectedTab?.isHome == true { return }
        if selectedTab?.isLoading == true {
            webViews[selectedTabID]?.stopLoading()
            updateTab(selectedTabID) { $0.isLoading = false }
        } else {
            webViews[selectedTabID]?.reload()
        }
    }

    func focusSelectedWebView() {
        guard let webView = webViews[selectedTabID] else { return }
        webView.window?.makeFirstResponder(webView)
    }

    // MARK: - Zoom

    func zoomIn() {
        guard let webView = webViews[selectedTabID] else { return }
        webView.pageZoom = min(webView.pageZoom + 0.1, 4.0)
        showZoomFeedback(webView.pageZoom)
    }

    func zoomOut() {
        guard let webView = webViews[selectedTabID] else { return }
        webView.pageZoom = max(webView.pageZoom - 0.1, 0.25)
        showZoomFeedback(webView.pageZoom)
    }

    func zoomReset() {
        webViews[selectedTabID]?.pageZoom = 1.0
        showZoomFeedback(1.0)
    }

    private func showZoomFeedback(_ zoom: CGFloat) {
        let percent = Int((zoom * 100).rounded())
        zoomFeedback = percent == 100 ? "Actual Size" : "\(percent)%"
    }

    func clearZoomFeedback() {
        zoomFeedback = nil
    }

    // MARK: - Find-in-page

    func toggleFindBar() {
        guard selectedTab?.isHome == false else { return }
        if showFindBar {
            dismissFind()
        } else {
            showFindBar = true
            findQuery = ""
            findMatchIndex = 0
            findMatchCount = 0
        }
    }

    func performFind(forward: Bool = true) {
        guard !findQuery.isEmpty else { return }
        findBackwards = !forward
        findTrigger += 1
    }

    func dismissFind() {
        showFindBar = false
        findQuery = ""
        findMatchIndex = 0
        findMatchCount = 0
        findBackwards = false
    }

    // MARK: - Tab mutation

    func updateTab(_ id: UUID, _ mutate: (inout BrowserTab) -> Void) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        mutate(&tabs[index])
    }

    func syncNavigationState(for id: UUID) {
        guard let webView = webViews[id], let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        guard !tabs[index].isHome else { return }
        tabs[index].canGoBack = webView.canGoBack
        tabs[index].canGoForward = webView.canGoForward
        tabs[index].isLoading = webView.isLoading
        tabs[index].estimatedProgress = webView.estimatedProgress
        if let url = webView.url, !url.absoluteString.isEmpty, url.absoluteString != "about:blank" {
            tabs[index].url = url
            tabs[index].title = Self.displayTitle(webTitle: webView.title, url: url)
        }
    }

    func webViewDidUpdate(tabID: UUID, webView: WKWebView) {
        guard webViews[tabID] === webView,
              let index = tabs.firstIndex(where: { $0.id == tabID }),
              !tabs[index].isHome
        else { return }

        if tabs[index].isLoading != webView.isLoading {
            tabs[index].isLoading = webView.isLoading
        }
        if tabs[index].canGoBack != webView.canGoBack {
            tabs[index].canGoBack = webView.canGoBack
        }
        if tabs[index].canGoForward != webView.canGoForward {
            tabs[index].canGoForward = webView.canGoForward
        }
        if tabs[index].estimatedProgress != webView.estimatedProgress {
            tabs[index].estimatedProgress = webView.estimatedProgress
        }
        if let url = webView.url,
           !url.absoluteString.isEmpty,
           url.absoluteString != "about:blank"
        {
            let newTitle = Self.displayTitle(webTitle: webView.title, url: url)
            if tabs[index].url != url || tabs[index].title != newTitle {
                tabs[index].url = url
                tabs[index].title = newTitle
                persistSession()
            }
        }
    }

    // MARK: - Session persistence

    private struct SessionTab: Codable {
        var url: String?
        var title: String
    }

    private struct Session: Codable {
        var tabs: [SessionTab]
        var selectedIndex: Int
    }

    private static func restoreSession(from userDefaults: UserDefaults) -> (tabs: [BrowserTab], selectedID: UUID) {
        guard let data = userDefaults.data(forKey: sessionKey),
              let session = try? JSONDecoder().decode(Session.self, from: data),
              !session.tabs.isEmpty
        else {
            let first = BrowserTab.home()
            return ([first], first.id)
        }
        let tabs = session.tabs.map { saved -> BrowserTab in
            var tab = BrowserTab.home()
            if let urlString = saved.url, let url = URL(string: urlString) {
                tab.url = url
                tab.isHome = false
                tab.title = saved.title
            }
            return tab
        }
        let index = min(max(0, session.selectedIndex), tabs.count - 1)
        return (tabs, tabs[index].id)
    }

    private func persistSession() {
        let session = Session(
            tabs: tabs.map {
                SessionTab(
                    url: $0.isHome ? nil : $0.url?.absoluteString,
                    title: $0.isHome ? "New Tab" : $0.title
                )
            },
            selectedIndex: tabs.firstIndex { $0.id == selectedTabID } ?? 0
        )
        if let data = try? JSONEncoder().encode(session) {
            userDefaults.set(data, forKey: Self.sessionKey)
        }
    }

    static func displayTitle(webTitle: String?, url: URL?) -> String {
        let trimmedTitle = webTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedTitle.isEmpty ? NavigationInput.title(for: url) : trimmedTitle
    }
}
