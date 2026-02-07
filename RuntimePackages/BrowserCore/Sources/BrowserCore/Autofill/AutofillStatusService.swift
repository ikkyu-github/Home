import Foundation
import SafariLikeContracts

public protocol AutofillSystemChecking: AnyObject {
    func checkAvailability() async -> AutofillAvailability
}

/// Best-effort status cache for debug/diagnostics UI.
///
/// Privacy contract:
/// - Stores **no** secrets.
/// - Stores **no** per-site information.
/// - Never persists private-browsing hints (this service is in-memory only).
public actor AutofillStatusService {
    private let checker: (any AutofillSystemChecking)?

    private var lastKnown: AutofillAvailability?

    public init(checker: (any AutofillSystemChecking)? = nil) {
        self.checker = checker
    }

    public func lastKnownAvailability() -> AutofillAvailability? {
        lastKnown
    }

    @discardableResult
    public func refresh() async -> AutofillAvailability? {
        guard let checker else { return lastKnown }
        let availability = await checker.checkAvailability()
        lastKnown = availability
        return availability
    }
}
