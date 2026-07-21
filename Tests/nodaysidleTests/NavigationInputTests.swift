import XCTest
@testable import nodaysidle

final class NavigationInputTests: XCTestCase {
    func testExplicitWebSchemesArePreserved() {
        XCTAssertEqual(resolve("http://example.com"), "http://example.com")
        XCTAssertEqual(resolve("https://example.com/path"), "https://example.com/path")
    }

    func testLoopbackTargetsDefaultToHTTP() {
        XCTAssertEqual(resolve("localhost:8080"), "http://localhost:8080")
        XCTAssertEqual(resolve("127.0.0.1:3000"), "http://127.0.0.1:3000")
        XCTAssertEqual(resolve("[::1]:4000"), "http://[::1]:4000")
    }

    func testRemoteHostsAndAddressesDefaultToHTTPS() {
        XCTAssertEqual(resolve("example.com"), "https://example.com")
        XCTAssertEqual(resolve("localhost.example.com"), "https://localhost.example.com")
        XCTAssertEqual(resolve("192.168.1.20:8080"), "https://192.168.1.20:8080")
        XCTAssertEqual(resolve("8.8.8.8"), "https://8.8.8.8")
    }

    func testPlainWordsAndSpacedInputUseSearch() {
        XCTAssertEqual(resolve("swift"), "https://duckduckgo.com/?q=swift")
        XCTAssertEqual(resolve("fish & chips"), "https://duckduckgo.com/?q=fish%20%26%20chips")
        XCTAssertEqual(resolve("c++"), "https://duckduckgo.com/?q=c%2B%2B")
    }

    func testWhitespaceOnlyInputIsRejected() {
        XCTAssertNil(NavigationInput.resolve("   \n", engine: .duckduckgo))
    }

    private func resolve(_ input: String) -> String? {
        NavigationInput.resolve(input, engine: .duckduckgo)?.absoluteString
    }
}
