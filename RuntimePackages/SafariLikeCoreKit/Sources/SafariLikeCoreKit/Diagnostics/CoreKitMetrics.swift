import Foundation

/// Lightweight, ship-safe CoreKit runtime counters.
///
/// This is intentionally CoreKit-only and UI-agnostic. Higher layers may *read* snapshots for
/// diagnostics, but writes should be cheap and deterministic.
public enum CoreKitMetrics {
    public struct Snapshot: Sendable {
        public let generatedAt: Date

        public let webViewConstructedCount: Int

        public let poolBorrowAlreadyLeasedCount: Int
        public let poolBorrowReusedSameTabCount: Int
        public let poolBorrowReusedOtherTabCount: Int
        public let poolBorrowCreatedNewCount: Int

        public let poolReturnLeaseCount: Int
        public let poolDiscardTabCount: Int
        public let poolOversubscribedCount: Int

        public let poolEvictedIdleCount: Int
        public let poolEvictedLeasedCount: Int

        public let tabActivationAttemptCount: Int
        public let tabActivationSuppressedCount: Int
        public let tabActivationGuardRejectedCount: Int
        public let tabActivationMissingPoolSuppressedCount: Int
        public let tabActivationSucceededCount: Int

        public let tabDeactivatedWarmCount: Int
        public let tabDeactivatedColdCount: Int

        public let loginFormDetectedCount: Int
        public let signupFormDetectedCount: Int

        public let countsByPoolLabel: [String: Int]
    }

    @MainActor
    private struct State {
        var webViewConstructedCount: Int = 0

        var poolBorrowAlreadyLeasedCount: Int = 0
        var poolBorrowReusedSameTabCount: Int = 0
        var poolBorrowReusedOtherTabCount: Int = 0
        var poolBorrowCreatedNewCount: Int = 0

        var poolReturnLeaseCount: Int = 0
        var poolDiscardTabCount: Int = 0
        var poolOversubscribedCount: Int = 0

        var poolEvictedIdleCount: Int = 0
        var poolEvictedLeasedCount: Int = 0

        var tabActivationAttemptCount: Int = 0
        var tabActivationSuppressedCount: Int = 0
        var tabActivationGuardRejectedCount: Int = 0
        var tabActivationMissingPoolSuppressedCount: Int = 0
        var tabActivationSucceededCount: Int = 0

        var tabDeactivatedWarmCount: Int = 0
        var tabDeactivatedColdCount: Int = 0

        var loginFormDetectedCount: Int = 0
        var signupFormDetectedCount: Int = 0

        var countsByPoolLabel: [String: Int] = [:]

        func snapshot() -> Snapshot {
            Snapshot(
                generatedAt: Date(),
                webViewConstructedCount: webViewConstructedCount,
                poolBorrowAlreadyLeasedCount: poolBorrowAlreadyLeasedCount,
                poolBorrowReusedSameTabCount: poolBorrowReusedSameTabCount,
                poolBorrowReusedOtherTabCount: poolBorrowReusedOtherTabCount,
                poolBorrowCreatedNewCount: poolBorrowCreatedNewCount,
                poolReturnLeaseCount: poolReturnLeaseCount,
                poolDiscardTabCount: poolDiscardTabCount,
                poolOversubscribedCount: poolOversubscribedCount,
                poolEvictedIdleCount: poolEvictedIdleCount,
                poolEvictedLeasedCount: poolEvictedLeasedCount,
                tabActivationAttemptCount: tabActivationAttemptCount,
                tabActivationSuppressedCount: tabActivationSuppressedCount,
                tabActivationGuardRejectedCount: tabActivationGuardRejectedCount,
                tabActivationMissingPoolSuppressedCount: tabActivationMissingPoolSuppressedCount,
                tabActivationSucceededCount: tabActivationSucceededCount,
                tabDeactivatedWarmCount: tabDeactivatedWarmCount,
                tabDeactivatedColdCount: tabDeactivatedColdCount,
                loginFormDetectedCount: loginFormDetectedCount,
                signupFormDetectedCount: signupFormDetectedCount,
                countsByPoolLabel: countsByPoolLabel
            )
        }
    }

    @MainActor
    private static var state = State()

    // MARK: - Public (read)

    public nonisolated static func snapshot() async -> Snapshot {
        await MainActor.run { state.snapshot() }
    }

    // MARK: - Internal (write)

    @MainActor
    static func recordWebViewConstructed(poolLabel: String?) {
        state.webViewConstructedCount += 1
        if let poolLabel {
            state.countsByPoolLabel[poolLabel, default: 0] += 1
        }
    }

    @MainActor
    static func recordPoolBorrowAlreadyLeased() { state.poolBorrowAlreadyLeasedCount += 1 }
    @MainActor
    static func recordPoolBorrowReusedSameTab() { state.poolBorrowReusedSameTabCount += 1 }
    @MainActor
    static func recordPoolBorrowReusedOtherTab() { state.poolBorrowReusedOtherTabCount += 1 }
    @MainActor
    static func recordPoolBorrowCreatedNew() { state.poolBorrowCreatedNewCount += 1 }

    @MainActor
    static func recordPoolReturnLease() { state.poolReturnLeaseCount += 1 }
    @MainActor
    static func recordPoolDiscardTab() { state.poolDiscardTabCount += 1 }
    @MainActor
    static func recordPoolOversubscribed() { state.poolOversubscribedCount += 1 }

    @MainActor
    static func recordPoolEvictedIdle() { state.poolEvictedIdleCount += 1 }
    @MainActor
    static func recordPoolEvictedLeased() { state.poolEvictedLeasedCount += 1 }

    @MainActor
    static func recordTabActivationAttempt() { state.tabActivationAttemptCount += 1 }
    @MainActor
    static func recordTabActivationSuppressed() { state.tabActivationSuppressedCount += 1 }
    @MainActor
    static func recordTabActivationGuardRejected() { state.tabActivationGuardRejectedCount += 1 }
    @MainActor
    static func recordTabActivationMissingPoolSuppressed() { state.tabActivationMissingPoolSuppressedCount += 1 }
    @MainActor
    static func recordTabActivationSucceeded() { state.tabActivationSucceededCount += 1 }

    @MainActor
    static func recordTabDeactivatedWarm() { state.tabDeactivatedWarmCount += 1 }
    @MainActor
    static func recordTabDeactivatedCold() { state.tabDeactivatedColdCount += 1 }

    @MainActor
    static func recordLoginFormDetected() { state.loginFormDetectedCount += 1 }

    @MainActor
    static func recordSignupFormDetected() { state.signupFormDetectedCount += 1 }
}
