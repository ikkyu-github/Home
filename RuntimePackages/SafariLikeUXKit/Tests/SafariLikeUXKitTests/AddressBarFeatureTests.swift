import XCTest
import SafariLikeUXKit
import SafariLikeContracts

final class AddressBarFeatureTests: XCTestCase {
    func test_focusThenTyping_entersEditing() {
        var feature = AddressBarFeature(initialURLString: "https://example.com")
        var state = feature.snapshot().state

        XCTAssertEqual(state, .idle(urlDisplayed: "example.com", security: .secure))

        _ = feature.reduce(state: &state, event: .tapAddressBar)
        if case .focused(let draft) = state {
            XCTAssertEqual(draft, "https://example.com")
        } else {
            XCTFail("Expected focused state")
        }

        _ = feature.reduce(state: &state, event: .textChanged("apple"))
        XCTAssertEqual(state, .editing(queryOrURL: "apple"))
    }

    func test_submitFromEditing_entersLoading_andEmitsEffect() {
        var feature = AddressBarFeature(initialURLString: "https://example.com")
        var state = feature.snapshot().state

        _ = feature.reduce(state: &state, event: .tapAddressBar)
        _ = feature.reduce(state: &state, event: .textChanged("https://apple.com"))

        let effects = feature.reduce(state: &state, event: .submit)

        if case .loading(let progress, let urlDisplayed, let security) = state {
            XCTAssertNil(progress)
            XCTAssertEqual(urlDisplayed, "https://apple.com")
            XCTAssertEqual(security, .secure)
        } else {
            XCTFail("Expected loading state")
        }

        XCTAssertEqual(effects, [.openURLString("https://apple.com", force: false)])
    }

    func test_cancelEditing_restoresIdle_andEmitsCancel() {
        var feature = AddressBarFeature(initialURLString: "https://example.com")
        var state = feature.snapshot().state

        _ = feature.reduce(state: &state, event: .tapAddressBar)
        _ = feature.reduce(state: &state, event: .textChanged("foo"))

        let effects = feature.reduce(state: &state, event: .cancelEditing)

        XCTAssertEqual(state, .idle(urlDisplayed: "example.com", security: .secure))
        XCTAssertEqual(effects, [.cancel])
    }

    func test_snapshotRestore_restoresDraftAcrossInstances() {
        var feature = AddressBarFeature(initialURLString: "https://example.com")
        var state = feature.snapshot().state

        _ = feature.reduce(state: &state, event: .tapAddressBar)
        _ = feature.reduce(state: &state, event: .textChanged("foo"))

        let snapshot = feature.snapshot()

        var restored = AddressBarFeature(initialURLString: "about:blank")
        restored.restore(snapshot)

        XCTAssertEqual(restored.snapshot(), snapshot)
    }
}
