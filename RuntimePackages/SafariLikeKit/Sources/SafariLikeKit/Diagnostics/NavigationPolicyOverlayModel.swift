import Foundation
import Combine
import SafariLikeCoreKit
import SafariLikeContracts
/// Shared model backing the Safari-like policy decision debug overlay.
///
/// NOTE: Model compiles in all build configurations; the overlay view is DEBUG-only.
@MainActor
public final class NavigationPolicyOverlayModel: ObservableObject {
    public static let enabledDefaultsKey = "app.policy.overlay.enabled"
    @Published public var isVisible: Bool
    @Published public private(set) var lastDecisionSummary: String = "—"
    @Published public private(set) var lastDecisionURL: String = "—"
    @Published public private(set) var lastDecisionTabID: String = "—"
    public init() {
        #if DEBUG
        if let value = UserDefaults.standard.object(forKey: Self.enabledDefaultsKey) as? Bool {
            self.isVisible = value
        } else {
            self.isVisible = false
        }
        #else
        self.isVisible = false
        #endif
    }
    public func setVisible(_ visible: Bool) {
        isVisible = visible
        UserDefaults.standard.set(visible, forKey: Self.enabledDefaultsKey)
    }
    public func toggle() {
        setVisible(!isVisible)
    }
    public func record(journalEvent: SessionJournalEvent) {
        guard journalEvent.type == .policyDecision else { return }
        lastDecisionURL = journalEvent.url ?? "—"
        lastDecisionTabID = journalEvent.tabID?.uuidString ?? "—"
        if let details = journalEvent.details,
           let data = details.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(SafariLikeCoreKit.NavigationPolicyDecision.self, from: data)
        {
            let host = URL(string: decoded.input.urlString)?.host ?? "(no-host)"
            let reason = decoded.reason.map { " reason=\($0)" } ?? ""
            lastDecisionSummary = "\(decoded.point.rawValue) \(decoded.outcome.rawValue) host=\(host)\(reason)"
        } else {
            lastDecisionSummary = journalEvent.details ?? "(no details)"
        }
    }
}
