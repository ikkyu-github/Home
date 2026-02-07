import Foundation
import SafariLikeContracts

public struct ParityAuditSnapshot: Sendable, Hashable {
    public var sceneCount: Int
    public var activeTabCount: Int
    public var activeWebViewCount: Int
    public var activeWebViewBudget: Int

    public var hasCrossSceneWebViewOwnershipViolation: Bool

    /// True if private session data is persisted when it should not be.
    public var hasPrivatePersistenceViolation: Bool

    public var speculativeLoadsInFlight: Int
    public var speculativeLoadsCap: Int

    public var telemetry: [TelemetryEvent]

    public init(
        sceneCount: Int,
        activeTabCount: Int,
        activeWebViewCount: Int,
        activeWebViewBudget: Int,
        hasCrossSceneWebViewOwnershipViolation: Bool,
        hasPrivatePersistenceViolation: Bool,
        speculativeLoadsInFlight: Int,
        speculativeLoadsCap: Int,
        telemetry: [TelemetryEvent]
    ) {
        self.sceneCount = sceneCount
        self.activeTabCount = activeTabCount
        self.activeWebViewCount = activeWebViewCount
        self.activeWebViewBudget = activeWebViewBudget
        self.hasCrossSceneWebViewOwnershipViolation = hasCrossSceneWebViewOwnershipViolation
        self.hasPrivatePersistenceViolation = hasPrivatePersistenceViolation
        self.speculativeLoadsInFlight = speculativeLoadsInFlight
        self.speculativeLoadsCap = speculativeLoadsCap
        self.telemetry = telemetry
    }
}

public struct ParityAuditRunner: Sendable {
    public init() {}

    public func run(snapshot: ParityAuditSnapshot) -> ParityReport {
        var results: [ParityCheckResult] = []

        // Architecture (best-effort): these are validated by build scripts in this repo.
        results.append(.init(
            checkID: "architecture.layering",
            status: .warn,
            message: "Validated by build tooling (see Dev/Tools/Scripts/safari_parity_check.sh); not re-verified at runtime."
        ))
        results.append(.init(
            checkID: "architecture.wkwebview.creationSite",
            status: .warn,
            message: "WKWebView construction should route through SafariLikeCoreKit.WebViewPool.makeWebView; build script enforces construction sites."
        ))

        // Runtime budgets.
        let budgetOk = snapshot.activeWebViewCount <= snapshot.activeWebViewBudget
        results.append(.init(
            checkID: "runtime.webviews.budget",
            status: budgetOk ? .pass : .fail,
            message: budgetOk
                ? "Active webviews within budget (\(snapshot.activeWebViewCount)/\(snapshot.activeWebViewBudget))."
                : "Active webviews exceed budget (\(snapshot.activeWebViewCount)/\(snapshot.activeWebViewBudget))."
        ))

        let ownershipOk = snapshot.hasCrossSceneWebViewOwnershipViolation == false
        results.append(.init(
            checkID: "runtime.webviews.sceneOwnership",
            status: ownershipOk ? .pass : .fail,
            message: ownershipOk
                ? "No cross-scene WKWebView ownership detected."
                : "Cross-scene WKWebView ownership violation detected."
        ))

        // Privacy.
        let privateOk = snapshot.hasPrivatePersistenceViolation == false
        results.append(.init(
            checkID: "privacy.privatePersistence",
            status: privateOk ? .pass : .fail,
            message: privateOk
                ? "No private persistence violations detected."
                : "Private profile persistence violation detected (private data persisted)."
        ))

        let telemetryOk = Self.telemetryHasNoForbiddenKeys(snapshot.telemetry)
        results.append(.init(
            checkID: "privacy.telemetry.nonPII",
            status: telemetryOk ? .pass : .fail,
            message: telemetryOk
                ? "Telemetry contains no forbidden keys/URL-like values."
                : "Telemetry appears to contain forbidden keys or URL-like values; investigate sanitization."
        ))

        // Performance.
        let speculativeOk = snapshot.speculativeLoadsInFlight <= snapshot.speculativeLoadsCap
        results.append(.init(
            checkID: "performance.speculativeLoads.cap",
            status: speculativeOk ? .pass : .fail,
            message: speculativeOk
                ? "Speculative loads within cap (\(snapshot.speculativeLoadsInFlight)/\(snapshot.speculativeLoadsCap))."
                : "Speculative loads exceed cap (\(snapshot.speculativeLoadsInFlight)/\(snapshot.speculativeLoadsCap))."
        ))

        // Determinism: stable order by checkID.
        results.sort { $0.checkID < $1.checkID }
        return ParityReport(results: results)
    }

    public static func telemetryHasNoForbiddenKeys(_ telemetry: [TelemetryEvent]) -> Bool {
        for event in telemetry {
            for (key, value) in event.attributes {
                let kLower = key.lowercased()
                if TelemetryPIIRule.forbiddenKeySubstrings.contains(where: { kLower.contains($0) }) {
                    return false
                }
                let vLower = value.lowercased()
                if vLower.contains("://") || vLower.hasPrefix("http") || vLower.contains("www.") {
                    return false
                }
            }
        }
        return true
    }
}
