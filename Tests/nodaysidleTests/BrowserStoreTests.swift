import Foundation
import XCTest
@testable import nodaysidle

@MainActor
final class BrowserStoreTests: XCTestCase {
    func testHomePreservesCurrentPageAndBackReturnsToIt() {
        withIsolatedDefaults { defaults in
            let store = BrowserStore(userDefaults: defaults)

            store.navigateSelected(to: "example.com")
            let pageURL = store.selectedTab?.url

            store.goHome()
            XCTAssertTrue(store.selectedTab?.isHome == true)
            XCTAssertEqual(store.selectedTab?.url, pageURL)
            XCTAssertTrue(store.selectedTab?.canGoBack == true)
            XCTAssertFalse(store.selectedTab?.isLoading == true)
            XCTAssertEqual(store.pendingNewTabFocusID, store.selectedTabID)

            store.goBack()
            XCTAssertFalse(store.selectedTab?.isHome == true)
            XCTAssertEqual(store.selectedTab?.url, pageURL)
            XCTAssertEqual(store.selectedTab?.title, "example.com")
            XCTAssertNil(store.pendingNewTabFocusID)
        }
    }

    func testSessionRestoresPageTabsAndCleanHomeTabs() {
        withIsolatedDefaults { defaults in
            let store = BrowserStore(userDefaults: defaults)
            store.navigateSelected(to: "example.com")
            store.newTab()

            let restored = BrowserStore(userDefaults: defaults)
            XCTAssertEqual(restored.tabs.count, 2)
            XCTAssertEqual(restored.tabs[0].url?.absoluteString, "https://example.com")
            XCTAssertFalse(restored.tabs[0].isHome)
            XCTAssertTrue(restored.tabs[1].isHome)
            XCTAssertNil(restored.tabs[1].url)
            XCTAssertEqual(restored.selectedTabID, restored.tabs[1].id)
        }
    }

    func testClosedTabCanBeReopened() {
        withIsolatedDefaults { defaults in
            let store = BrowserStore(userDefaults: defaults)
            store.newTab()
            let closedID = store.selectedTabID

            store.closeTab(closedID)
            XCTAssertEqual(store.tabs.count, 1)
            XCTAssertTrue(store.canUndoCloseTab)

            store.undoCloseTab()
            XCTAssertEqual(store.tabs.count, 2)
            XCTAssertTrue(store.selectedTab?.isHome == true)
        }
    }

    func testEmptyWebTitleFallsBackToHost() {
        let url = URL(string: "https://example.com/path")
        XCTAssertEqual(BrowserStore.displayTitle(webTitle: nil, url: url), "example.com")
        XCTAssertEqual(BrowserStore.displayTitle(webTitle: "  ", url: url), "example.com")
        XCTAssertEqual(BrowserStore.displayTitle(webTitle: "Example", url: url), "Example")
    }

    private func withIsolatedDefaults(_ body: (UserDefaults) -> Void) {
        let suiteName = "nodaysidle.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        body(defaults)
    }
}
