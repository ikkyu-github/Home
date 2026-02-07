import XCTest
@testable import SafariLikeKit
import UIKit

@MainActor
final class SceneMetricsTests: XCTestCase {

    func testUpdateDoesNotCommitStableValuesDuringRotation() {
        let metrics = SceneMetrics()

        // Establish known stable values via settle path (no debounced sleep needed).
        metrics.rotationWillBegin()
        metrics.rotationDidEnd()
        metrics.noteLayoutPass()
        metrics.noteLayoutPass()
        metrics.update(
            size: CGSize(width: 400, height: 800),
            insets: UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0),
            orientation: .portrait
        )
        metrics.update(
            size: CGSize(width: 400, height: 800),
            insets: UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0),
            orientation: .portrait
        )

        let committedEpochBefore = metrics.stableCommittedEpoch
        let stableInsetsBefore = metrics.stableInsets
        XCTAssertEqual(committedEpochBefore, metrics.stableEpoch)

        // Begin rotation and send an update. It may update live values, but must not commit stable.
        metrics.rotationWillBegin()
        metrics.update(
            size: CGSize(width: 800, height: 400),
            insets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
            orientation: .landscapeLeft
        )

        XCTAssertTrue(metrics.rotationInProgress)
        XCTAssertEqual(metrics.stableCommittedEpoch, committedEpochBefore)
        XCTAssertEqual(metrics.stableInsets.top, stableInsetsBefore.top, accuracy: 0.001)
    }

    func testDebouncedCommitIsBlockedWhenEpochChanges() async {
        let metrics = SceneMetrics()

        // Establish stable committed epoch = 1 via settle sampling.
        metrics.rotationWillBegin() // stableEpoch = 1
        metrics.rotationDidEnd()
        metrics.noteLayoutPass()
        metrics.noteLayoutPass()
        metrics.update(
            size: CGSize(width: 400, height: 800),
            insets: UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0),
            orientation: .portrait
        )
        metrics.update(
            size: CGSize(width: 400, height: 800),
            insets: UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0),
            orientation: .portrait
        )

        XCTAssertEqual(metrics.stableEpoch, 1)
        XCTAssertEqual(metrics.stableCommittedEpoch, 1)

        let stableInsetsBefore = metrics.stableInsets

        // Schedule a debounced commit on the current epoch.
        metrics.update(
            size: CGSize(width: 401, height: 800),
            insets: UIEdgeInsets(top: 11, left: 0, bottom: 0, right: 0),
            orientation: .portrait
        )

        // Immediately begin a rotation, which increments the epoch and cancels the pending debounced commit.
        metrics.rotationWillBegin() // stableEpoch = 2

        // Wait longer than debounceNanoseconds (140ms) to ensure any scheduled task would have fired.
        try? await Task.sleep(nanoseconds: 260_000_000)

        // Stable values must remain from before; no cross-epoch commit.
        XCTAssertEqual(metrics.stableCommittedEpoch, 1)
        XCTAssertEqual(metrics.stableInsets.top, stableInsetsBefore.top, accuracy: 0.001)
    }
}
