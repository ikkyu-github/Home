import XCTest
@testable import BrowserCore
import SafariLikeContracts

final class ParityAuditRunnerTests: XCTestCase {

    func testTelemetryForbiddenKeyFails() {
        let runner = ParityAuditRunner()
        let snapshot = ParityAuditSnapshot(
            sceneCount: 1,
            activeTabCount: 1,
            activeWebViewCount: 1,
            activeWebViewBudget: 2,
            hasCrossSceneWebViewOwnershipViolation: false,
            hasPrivatePersistenceViolation: false,
            speculativeLoadsInFlight: 0,
            speculativeLoadsCap: 1,
            telemetry: [
                .init(type: .appLaunch, attributes: ["url": "nope"]) // forbidden key
            ]
        )

        let report = runner.run(snapshot: snapshot)
        let nonPII = report.results.first(where: { $0.checkID == "privacy.telemetry.nonPII" })
        XCTAssertEqual(nonPII?.status, .fail)
    }

    func testWebViewBudgetFail() {
        let runner = ParityAuditRunner()
        let snapshot = ParityAuditSnapshot(
            sceneCount: 1,
            activeTabCount: 3,
            activeWebViewCount: 3,
            activeWebViewBudget: 2,
            hasCrossSceneWebViewOwnershipViolation: false,
            hasPrivatePersistenceViolation: false,
            speculativeLoadsInFlight: 0,
            speculativeLoadsCap: 1,
            telemetry: []
        )

        let report = runner.run(snapshot: snapshot)
        let budget = report.results.first(where: { $0.checkID == "runtime.webviews.budget" })
        XCTAssertEqual(budget?.status, .fail)
    }
}
