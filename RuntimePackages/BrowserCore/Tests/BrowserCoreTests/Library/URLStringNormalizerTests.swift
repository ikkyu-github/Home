import XCTest
@testable import BrowserCore
import SafariLikeContracts

final class URLStringNormalizerTests: XCTestCase {
    func testCanonicalizationAddsHTTPSWhenMissingScheme() {
        let n = URLStringNormalizer()
        let c = n.canonicalize("example.com")
        XCTAssertEqual(c?.normalized, "https://example.com/")
    }

    func testCanonicalizationLowercasesHostAndStripsFragment() {
        let n = URLStringNormalizer()
        let c = n.canonicalize("https://EXAMPLE.com/path#section")
        XCTAssertEqual(c?.normalized, "https://example.com/path")
    }

    func testDefaultPortIsRemoved() {
        let n = URLStringNormalizer()
        let c = n.canonicalize("https://example.com:443/")
        XCTAssertEqual(c?.normalized, "https://example.com/")
    }
}
