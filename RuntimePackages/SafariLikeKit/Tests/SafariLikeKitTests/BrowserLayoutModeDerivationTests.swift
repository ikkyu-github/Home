import XCTest
@testable import SafariLikeKit

final class BrowserLayoutModeDerivationTests: XCTestCase {

    func testFromChromeStyle_phonePortraitSafariMapsToPhonePortrait() {
        XCTAssertEqual(BrowserLayoutMode.from(chromeStyle: .phonePortraitSafari), .phonePortrait)
    }

    func testFromChromeStyle_padLandscapeSafariMapsToTabletLandscape() {
        XCTAssertEqual(BrowserLayoutMode.from(chromeStyle: .padLandscapeSafari), .tabletLandscape)
    }
}
