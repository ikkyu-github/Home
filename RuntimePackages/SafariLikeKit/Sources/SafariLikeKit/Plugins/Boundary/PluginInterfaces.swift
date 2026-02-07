import Foundation
import SafariLikeCoreKit
public protocol PolicyPluginBoundary: Sendable {
    var id: String { get }
    var capabilities: PluginCapabilities { get }
    func navigationDecision(ctx: NavigationContext) async -> PolicyDecision?
    func resourceDecision(ctx: ResourceContext) async -> PolicyDecision?
    func privacyDecision(ctx: PrivacyContext) async -> PolicyDecision?
}
public extension PolicyPluginBoundary {
    func navigationDecision(ctx: NavigationContext) async -> PolicyDecision? { nil }
    func resourceDecision(ctx: ResourceContext) async -> PolicyDecision? { nil }
    func privacyDecision(ctx: PrivacyContext) async -> PolicyDecision? { nil }
}
// NOTE: `WebViewLifecyclePlugin` is defined in SafariLikeContracts so third-party
// plugins can depend on Contracts only.
