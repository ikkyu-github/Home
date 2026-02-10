import Foundation
import SafariLikeCoreKit
/// Owns timeout timers only.
///
/// No UI, no WebKit, no state-machine decisions.
@MainActor
final class WatchdogController {
    private struct Key: Hashable {
        let tabID: UUID
        let kind: Kind
    }
    enum Kind: Hashable {
        case attachmentTimeout
    }
    private var tasks: [Key: Task<Void, Never>] = [:]
    func startAttachmentTimeout(
        tabID: UUID,
        timeoutSeconds: Double,
        onTimeout: @escaping @MainActor (UUID) -> Void
    ) {
        let key = Key(tabID: tabID, kind: .attachmentTimeout)
        tasks[key]?.cancel()
        tasks[key] = Task { @MainActor in
            let nanos = UInt64(timeoutSeconds * 1_000_000_000)
            do {
                try await Task.sleep(nanoseconds: nanos)
            } catch {
                return
            }
            guard Task.isCancelled == false else { return }
            onTimeout(tabID)
        }
    }
    func cancelAttachmentTimeout(tabID: UUID) {
        let key = Key(tabID: tabID, kind: .attachmentTimeout)
        tasks[key]?.cancel()
        tasks[key] = nil
    }
    func cancelAll() {
        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
    }
}
