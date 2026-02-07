import XCTest
@testable import BrowserCore
import SafariLikeContracts

final class InvariantEnforcerTests: XCTestCase {

    func testInvariantReleasePathReturnsFalse() throws {
        // This test validates the non-crashing semantics in RELEASE builds.
        // In DEBUG, InvariantEnforcer fails fast by design; we skip.
        #if DEBUG
        throw XCTSkip("InvariantEnforcer crashes in DEBUG by design")
        #else
        let ok = InvariantEnforcer.assertInvariant(
            false,
            "broken",
            category: .invariantViolation,
            context: CrashContextSnapshot(
                sceneID: "s",
                activeTabCount: 1,
                activeWebViewCount: 1,
                memoryPressureLevel: .normal,
                lastUserAction: "test"
            ),
            telemetry: nil
        )
        XCTAssertFalse(ok)
        #endif
    }
}
