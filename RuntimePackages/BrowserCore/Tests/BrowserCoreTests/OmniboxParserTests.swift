import XCTest
@testable import BrowserCore
import SafariLikeContracts

final class OmniboxParserTests: XCTestCase {
    private let template = DefaultURLs.SearchEngine.googleQuery

    func testEmptyIsNil() {
        XCTAssertNil(OmniboxParser.resolve("   ", searchEngineTemplateURL: template))
    }

    func testAboutBlankIsNil() {
        XCTAssertNil(OmniboxParser.resolve("about:blank", searchEngineTemplateURL: template))
    }

    func testWhitespaceBecomesSearch() {
        let r = OmniboxParser.resolve("hello world", searchEngineTemplateURL: template)
        XCTAssertEqual(r?.kind, .search)
        XCTAssertTrue(r?.resolvedURLString.contains("q=hello") == true)
    }

    func testDomainBecomesHttpsURL() {
        let r = OmniboxParser.resolve("example.com", searchEngineTemplateURL: template)
        XCTAssertEqual(r?.kind, .url)
        XCTAssertEqual(r?.resolvedURLString, "https://example.com")
    }

    func testHttpSchemeMissingSlashesIsFixed() {
        let r = OmniboxParser.resolve("http:example.com", searchEngineTemplateURL: template)
        XCTAssertEqual(r?.kind, .url)
        XCTAssertEqual(r?.resolvedURLString, "http://example.com")
    }

    func testLocalhostIsURL() {
        let r = OmniboxParser.resolve("localhost:8080", searchEngineTemplateURL: template)
        XCTAssertEqual(r?.kind, .url)
        XCTAssertEqual(r?.resolvedURLString, "https://localhost:8080")
    }

    func testIPv4IsURL() {
        let r = OmniboxParser.resolve("127.0.0.1:8080", searchEngineTemplateURL: template)
        XCTAssertEqual(r?.kind, .url)
        XCTAssertEqual(r?.resolvedURLString, "https://127.0.0.1:8080")
    }
}
