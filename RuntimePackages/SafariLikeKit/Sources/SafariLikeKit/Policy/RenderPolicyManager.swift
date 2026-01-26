import Foundation
import Combine
import SafariLikeCoreKit

/// Enforces a strict render budget for WKWebView attachment.
///
/// Policy:
/// - At most `maxRenderCount` WebContexts may be in `.active` at a time.
/// - Contexts not in budget are transitioned to `.suspended` (or `.snapshot`).
/// - Suspended contexts must not have their WKWebView in the SwiftUI view tree.
@MainActor
final class RenderPolicyManager: ObservableObject {
    @Published private(set) var activeContexts: [UUID] = []

    private let contextByID = NSMapTable<NSUUID, WebContext>(keyOptions: .strongMemory, valueOptions: .weakMemory)

    let maxRenderCount: Int = 2

    /// Mark a context as actively rendered now.
    func activate(_ context: WebContext) {
        contextByID.setObject(context, forKey: context.id as NSUUID)
        touch(context.id)
        context.renderState = .active
        enforceBudget()
    }

    /// Mark a context as no longer actively rendered.
    func deactivate(_ context: WebContext) {
        activeContexts.removeAll { $0 == context.id }
        if context.renderState == .active {
            context.renderState = .suspended
        }
    }

    private func touch(_ id: UUID) {
        activeContexts.removeAll { $0 == id }
        activeContexts.insert(id, at: 0)
    }

    private func enforceBudget() {
        guard activeContexts.count > maxRenderCount else { return }
        let overflow = activeContexts.suffix(activeContexts.count - maxRenderCount)
        for id in overflow {
            if let ctx = contextByID.object(forKey: id as NSUUID) {
                // Prefer snapshot mode so UI can show a captured image when available.
                // (If no snapshot exists, views will show a lightweight placeholder.)
                ctx.renderState = .snapshot
            }
        }
        activeContexts.removeLast(activeContexts.count - maxRenderCount)
    }
}
