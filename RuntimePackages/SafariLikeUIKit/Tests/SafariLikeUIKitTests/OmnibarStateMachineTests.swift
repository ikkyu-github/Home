import XCTest
@testable import SafariLikeUIKit

final class OmnibarStateMachineTests: XCTestCase {
    func testTapToFocused() {
        var m = OmnibarStateMachine(initial: .collapsed(showURL: true))
        m.handle(.onTapBar)
        guard case .focused = m.state else { return XCTFail("expected focused") }
    }

    func testTypeToSuggestions() {
        var m = OmnibarStateMachine(initial: .collapsed(showURL: true))
        m.handle(.onBeginEditing(text: ""))
        m.handle(.onTextChange(text: "apple"))
        guard case .showingSuggestions(let q) = m.state else { return XCTFail("expected showingSuggestions") }
        XCTAssertEqual(q, "apple")
    }

    func testSubmitUrlNavigatingLoadingCollapsed() {
        var m = OmnibarStateMachine(initial: .collapsed(showURL: true))
        m.handle(.onSubmit(text: "https://example.com"))
        guard case .navigating = m.state else { return XCTFail("expected navigating") }
        m.handle(.onNavigationCommit(url: URL(string: "https://example.com")!))
        guard case .loading = m.state else { return XCTFail("expected loading") }
        m.handle(.onLoadProgress(progress: 1.0))
        guard case .collapsed = m.state else { return XCTFail("expected collapsed") }
    }

    func testCancelToCollapsed() {
        var m = OmnibarStateMachine(initial: .focused(editingText: "x", selection: nil))
        m.handle(.onCancel)
        guard case .collapsed = m.state else { return XCTFail("expected collapsed") }
    }

    func testScrollWhileLoadingCollapsesShowURLToggle() {
        var m = OmnibarStateMachine(initial: .loading(progress: 0.3))
        m.handle(.onScroll(offset: 100))
        guard case .collapsed(let showURL) = m.state else { return XCTFail("expected collapsed") }
        XCTAssertFalse(showURL)
        m.handle(.onScroll(offset: 0))
        guard case .collapsed(let showURL2) = m.state else { return XCTFail("expected collapsed") }
        XCTAssertTrue(showURL2)
    }
}
