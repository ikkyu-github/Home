import XCTest
@testable import SafariLikeKit

final class AttachmentInvariantTests: XCTestCase {
    @MainActor
    func testInvariantViolationOnlyWhenRealityReadyAndTimedOut() {
        XCTAssertTrue(AttachmentCoordinator.isInvariantViolation(
            snapshotIsRealityReady: true,
            attachmentState: .timedOut
        ))

        XCTAssertFalse(AttachmentCoordinator.isInvariantViolation(
            snapshotIsRealityReady: false,
            attachmentState: .timedOut
        ))

        XCTAssertFalse(AttachmentCoordinator.isInvariantViolation(
            snapshotIsRealityReady: true,
            attachmentState: .attaching
        ))

        XCTAssertFalse(AttachmentCoordinator.isInvariantViolation(
            snapshotIsRealityReady: true,
            attachmentState: .ready
        ))

        XCTAssertFalse(AttachmentCoordinator.isInvariantViolation(
            snapshotIsRealityReady: true,
            attachmentState: .failed(reason: "x")
        ))
    }
}
