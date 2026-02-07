import Foundation

public struct TimingPolicy: Sendable {
    public var scrollSuggestDebounceSeconds: TimeInterval

    public init(
        scrollSuggestDebounceSeconds: TimeInterval = 0.25
    ) {
        self.scrollSuggestDebounceSeconds = scrollSuggestDebounceSeconds
    }
}

/// Centralized timing knobs for UI/runtime scheduling.
///
/// Keep all non-semantic delays (debounces/coalescing) here so they can be tuned,
/// and prefer state/animation-driven completion for UI transitions.
public enum Timing {
    /// Mutable by design (e.g. tests / tuning). Prefer setting once at app start.
    @MainActor public static var policy = TimingPolicy()

    /// Schedule work on the main actor after a policy-driven delay.
    @discardableResult
    public static func scheduleOnMain(
        after delaySeconds: TimeInterval,
        _ operation: @escaping @MainActor () -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            let nanos = UInt64(max(0, delaySeconds) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            operation()
        }
    }
}
