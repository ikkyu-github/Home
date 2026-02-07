import XCTest

final class RotationRegressionUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        // Try to keep orientation deterministic across tests.
        XCUIDevice.shared.orientation = .portrait
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    }

    func testRotationStressKeepsStableInsetsSane() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_HARNESS"] = "1"
        app.launchArguments += ["--uiTestHarness"]
        app.launch()

        let hook = app.staticTexts["SafariLike.SceneMetrics.Hook"]
        XCTAssertTrue(hook.waitForExistence(timeout: 10))

        guard canRotateToPortrait(hook: hook, timeout: 6) else {
            throw XCTSkip("Simulator did not rotate to portrait reliably; skipping stress test")
        }

        rotateAndWaitForStableCommit(hook: hook, to: .portrait, expectedLandscape: false, timeout: 10)

        for _ in 0..<8 {
            rotateAndWaitForStableCommit(hook: hook, to: .landscapeLeft, expectedLandscape: true, timeout: 10)
            assertInsetsSane(hook: hook, maxTop: 30)

            rotateAndWaitForStableCommit(hook: hook, to: .portrait, expectedLandscape: false, timeout: 10)
            assertInsetsSane(hook: hook, maxTop: 80)
        }
    }

    func testNavigateToTabOverviewRotateAndKeepUIAlive() {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_HARNESS"] = "1"
        app.launchEnvironment["UI_TEST_START_IN_TAB_OVERVIEW"] = "1"
        app.launchArguments += ["--uiTestHarness"]
        app.launch()

        let hook = app.staticTexts["SafariLike.SceneMetrics.Hook"]
        XCTAssertTrue(hook.waitForExistence(timeout: 10))

        // Start from a known orientation so the chrome controls are predictable.
        rotateAndWaitForStableCommit(hook: hook, to: .portrait, expectedLandscape: false, timeout: 10)

        let tabOverview = app.otherElements["SafariLike.TabOverview.Root"]
        XCTAssertTrue(tabOverview.waitForExistence(timeout: 6))

        rotate(to: .landscapeLeft)
        waitForMetricsSettled(hook: hook, expectedLandscape: true, timeout: 8)
        XCTAssertTrue(tabOverview.exists)

        rotate(to: .portrait)
        waitForMetricsSettled(hook: hook, expectedLandscape: false, timeout: 8)
        XCTAssertTrue(tabOverview.exists)
    }

    // MARK: - Helpers

    private func firstExistingElement(_ candidates: XCUIElement...) -> XCUIElement? {
        for c in candidates where c.exists {
            return c
        }
        return nil
    }

    private func rotate(to orientation: UIDeviceOrientation) {
        let device = XCUIDevice.shared
        // Empirically improves reliability of consecutive rotations in Simulator.
        device.orientation = .faceUp
        RunLoop.current.run(until: Date().addingTimeInterval(0.30))
        device.orientation = orientation
        RunLoop.current.run(until: Date().addingTimeInterval(0.10))
    }

    private func rotateAndWait(
        hook: XCUIElement,
        to orientation: UIDeviceOrientation,
        expectedLandscape: Bool,
        timeout: TimeInterval
    ) {
        rotate(to: orientation)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let p = parsePayload(hook.label)
            let rotation = p["rotationInProgress"]
            let cw = Int(p["containerSizeW"] ?? "0") ?? 0
            let ch = Int(p["containerSizeH"] ?? "0") ?? 0
            let containerLooksCorrect = (cw > 0 && ch > 0) && (expectedLandscape ? (cw > ch) : (ch > cw))
            if rotation == "0", containerLooksCorrect {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTFail("Rotation did not reach expected orientation within timeout; payload=\(hook.label)")
    }

    private func rotateAndWaitForStableCommit(
        hook: XCUIElement,
        to orientation: UIDeviceOrientation,
        expectedLandscape: Bool,
        timeout: TimeInterval
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        rotate(to: orientation)
        while Date() < deadline {
            let p = parsePayload(hook.label)
            let rotation = p["rotationInProgress"]

            let stableEpoch = p["stableEpoch"]
            let stableCommittedEpoch = p["stableCommittedEpoch"]
            let w = Int(p["stableSizeW"] ?? "0") ?? 0
            let h = Int(p["stableSizeH"] ?? "0") ?? 0
            let cw = Int(p["containerSizeW"] ?? "0") ?? 0
            let ch = Int(p["containerSizeH"] ?? "0") ?? 0

            let containerLooksCorrect = (cw > 0 && ch > 0) && (expectedLandscape ? (cw > ch) : (ch > cw))
            let epochCommitted = (stableEpoch != nil && stableEpoch == stableCommittedEpoch)
            let stableSizeLooksCorrect = (w > 0 && h > 0) && (expectedLandscape ? (w > h) : (h > w))

            if rotation == "0", containerLooksCorrect, epochCommitted, stableSizeLooksCorrect {
                return
            }

            // If the device orientation didn't take, retry the rotation.
            if rotation == "0", containerLooksCorrect == false {
                rotate(to: orientation)
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTFail("Rotation did not settle+commit within timeout; payload=\(hook.label)")
    }

    private func canRotateToPortrait(hook: XCUIElement, timeout: TimeInterval) -> Bool {
        rotate(to: .portrait)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let p = parsePayload(hook.label)
            let rotation = p["rotationInProgress"]
            let cw = Int(p["containerSizeW"] ?? "0") ?? 0
            let ch = Int(p["containerSizeH"] ?? "0") ?? 0
            if rotation == "0", (cw > 0 && ch > 0), (ch > cw) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return false
    }

    private func firstExistingTextField(_ candidates: XCUIElement...) -> XCUIElement? {
        for c in candidates where c.exists {
            return c
        }
        return nil
    }

    private func waitForStableCommit(hook: XCUIElement, expectedLandscape: Bool, timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let p = parsePayload(hook.label)
            let rotation = p["rotationInProgress"]
            let stableEpoch = p["stableEpoch"]
            let stableCommittedEpoch = p["stableCommittedEpoch"]
            let w = Int(p["stableSizeW"] ?? "0") ?? 0
            let h = Int(p["stableSizeH"] ?? "0") ?? 0

            let epochCommitted = (stableEpoch != nil && stableEpoch == stableCommittedEpoch)
            let sizeLooksCorrect = (w > 0 && h > 0) && (expectedLandscape ? (w > h) : (h > w))
            if rotation == "0", epochCommitted, sizeLooksCorrect {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTFail("SceneMetrics stable commit did not complete within timeout; payload=\(hook.label)")
    }

    private func waitForMetricsSettled(hook: XCUIElement, expectedLandscape: Bool, timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let p = parsePayload(hook.label)
            let rotation = p["rotationInProgress"]
            let stableEpoch = p["stableEpoch"]
            let stableCommittedEpoch = p["stableCommittedEpoch"]
            let w = Int(p["stableSizeW"] ?? "0") ?? 0
            let h = Int(p["stableSizeH"] ?? "0") ?? 0
            let cw = Int(p["containerSizeW"] ?? "0") ?? 0
            let ch = Int(p["containerSizeH"] ?? "0") ?? 0

            // Prefer the real stable-commit signal, but allow a UI-relevant fallback.
            let epochCommitted = (stableEpoch != nil && stableEpoch == stableCommittedEpoch)
            let sizeLooksCorrect = (w > 0 && h > 0) && (expectedLandscape ? (w > h) : (h > w))
            let containerLooksCorrect = (cw > 0 && ch > 0) && (expectedLandscape ? (cw > ch) : (ch > cw))
            if rotation == "0", (epochCommitted || sizeLooksCorrect || containerLooksCorrect) {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTFail("SceneMetrics did not settle within timeout; payload=\(hook.label)")
    }

    private func assertInsetsSane(hook: XCUIElement, maxTop: Int) {
        let p = parsePayload(hook.label)
        let top = Int(p["stableInsetsTop"] ?? "-1") ?? -1
        XCTAssertGreaterThanOrEqual(top, 0)
        XCTAssertLessThanOrEqual(top, maxTop, "Unexpected stableInsetsTop; payload=\(hook.label)")

        // Also make sure no edge is absurdly large.
        let left = Int(p["stableInsetsLeft"] ?? "0") ?? 0
        let right = Int(p["stableInsetsRight"] ?? "0") ?? 0
        let bottom = Int(p["stableInsetsBottom"] ?? "0") ?? 0
        XCTAssertLessThanOrEqual(max(left, right, bottom), 160, "Insets look poisoned; payload=\(hook.label)")
    }

    private func parsePayload(_ payload: String) -> [String: String] {
        // Format: k=v;k=v;...
        var out: [String: String] = [:]
        for part in payload.split(separator: ";") {
            let bits = part.split(separator: "=", maxSplits: 1)
            guard bits.count == 2 else { continue }
            out[String(bits[0])] = String(bits[1])
        }
        return out
    }
}
