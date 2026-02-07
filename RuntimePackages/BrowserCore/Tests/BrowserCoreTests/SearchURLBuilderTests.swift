import XCTest
@testable import BrowserCore
import SafariLikeContracts

final class SearchURLBuilderTests: XCTestCase {
    func testBuildsSearchURLWithQueryItemsEncoding() {
        let template = DefaultURLs.SearchEngine.googleQuery
        let urlString = SearchURLBuilder.buildSearchURLString(query: "a b", templateURL: template)
        XCTAssertNotNil(urlString)
        XCTAssertTrue(urlString?.contains("q=a%20b") == true)
    }
}
