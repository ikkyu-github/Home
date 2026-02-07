import Foundation
import Combine

/// UI-facing restore controller for web view attach/restore UX.
///
/// This is intentionally independent from diagnostics/tracing state.
@MainActor
public final class UXRestoreController: ObservableObject {

    public enum State: Equatable {
        case idle
        case restoring
        case timedOut
        case completed
    }

    public nonisolated static let defaultTimeoutSeconds: Double = 2.5

    @Published public private(set) var state: State = .idle

    private var timeoutTask: Task<Void, Never>?
    private let timeoutSeconds: Double

    public init(timeoutSeconds: Double = UXRestoreController.defaultTimeoutSeconds) {
        self.timeoutSeconds = timeoutSeconds
    }

    deinit {
        timeoutTask?.cancel()
    }

    public func markIdle() {
        timeoutTask?.cancel()
        timeoutTask = nil
        state = .idle
    }

    public func markRestoring() {
        state = .restoring
        armTimeout()
    }

    public func markCompleted() {
        timeoutTask?.cancel()
        timeoutTask = nil
        state = .completed
    }

    private func armTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { [timeoutSeconds] in
            let nanos = UInt64(timeoutSeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            if state == .restoring {
                state = .timedOut
            }
        }
    }
}
