import XCTest
@testable import SafariLikeKit

final class RelatedPresentationSuppressionTests: XCTestCase {

    func testEffectivePresentation_overviewActiveSuppressesOverlayAndSidebar() {
        XCTAssertEqual(
            RelatedPresentationPolicy.effectivePresentation(
                relatedPresentation: .overlay(edge: .bottom),
                overviewActive: true
            ),
            .hidden
        )

        XCTAssertEqual(
            RelatedPresentationPolicy.effectivePresentation(
                relatedPresentation: .sidebar(width: 320),
                overviewActive: true
            ),
            .hidden
        )
    }

    func testEffectivePresentation_overviewInactivePassthrough() {
        XCTAssertEqual(
            RelatedPresentationPolicy.effectivePresentation(
                relatedPresentation: .overlay(edge: .bottom),
                overviewActive: false
            ),
            .overlay(edge: .bottom)
        )

        XCTAssertEqual(
            RelatedPresentationPolicy.effectivePresentation(
                relatedPresentation: .sidebar(width: 320),
                overviewActive: false
            ),
            .sidebar(width: 320)
        )
    }
}
