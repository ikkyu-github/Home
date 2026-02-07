import Foundation
import SafariLikeCoreKit
enum PluginSandbox {
    static func withTimeout<T>(nanoseconds: UInt64, operation: @escaping @Sendable () async -> T) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(nanoseconds: nanoseconds)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}
public struct SandboxedPolicyProvider: PolicyProviding {
    public let id: String
    public let kind: PolicyProviderKind = .plugin
    public let priority: Int
    private let plugin: any PolicyPluginBoundary
    public init(plugin: any PolicyPluginBoundary, priority: Int = 0) {
        self.plugin = plugin
        self.id = plugin.id
        self.priority = priority
    }
    public func decideNavigation(_ ctx: NavigationContext) async -> PolicyDecision? {
        guard plugin.capabilities.contains(.proposeNavigationDecision) else { return nil }
        return (await PluginSandbox.withTimeout(nanoseconds: 200_000_000) { await plugin.navigationDecision(ctx: ctx) }) ?? nil
    }
    public func decideResource(_ ctx: ResourceContext) async -> PolicyDecision? {
        guard plugin.capabilities.contains(.proposeResourceDecision) else { return nil }
        return (await PluginSandbox.withTimeout(nanoseconds: 100_000_000) { await plugin.resourceDecision(ctx: ctx) }) ?? nil
    }
    public func decidePrivacy(_ ctx: PrivacyContext) async -> PolicyDecision? {
        guard plugin.capabilities.contains(.proposePrivacyDecision) else { return nil }
        return (await PluginSandbox.withTimeout(nanoseconds: 150_000_000) { await plugin.privacyDecision(ctx: ctx) }) ?? nil
    }
}
