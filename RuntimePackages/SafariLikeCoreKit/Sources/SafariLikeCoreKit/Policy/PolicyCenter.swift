import Foundation

public protocol PolicyProviding: Sendable {
    var id: String { get }
    var kind: PolicyProviderKind { get }
    var priority: Int { get }

    func decideNavigation(_ ctx: NavigationContext) async -> PolicyDecision?
    func decideResource(_ ctx: ResourceContext) async -> PolicyDecision?
    func decidePrivacy(_ ctx: PrivacyContext) async -> PolicyDecision?
}

public enum PolicyProviderKind: Sendable {
    case core
    case plugin
}

public struct PolicyEvent: Sendable, Equatable {
    public enum Domain: String, Sendable {
        case navigation
        case resource
        case privacy
    }

    public let domain: Domain
    public let providerID: String
    public let decision: PolicyDecision

    public init(domain: Domain, providerID: String, decision: PolicyDecision) {
        self.domain = domain
        self.providerID = providerID
        self.decision = decision
    }
}

public actor PolicyCenter {
    /// SAFE SINGLETON:
    /// - Process-wide policy registry and evaluator.
    /// - Must not store per-window/scene/tab mutable state.
    public static let shared = PolicyCenter()

    private var providers: [String: any PolicyProviding] = [:]
    private var order: [String] = []

    private var observers: [UUID: (@MainActor @Sendable (PolicyEvent) -> Void)] = [:]

    private init() {}

    /// No-op hook for lifecycle coordinators to explicitly flow scene context through the
    /// policy layer, without the policy center storing per-scene/tab mutable state.
    public func noteSceneEvent(
        _ name: String,
        context: SceneRuntimeContext
    ) {
        _ = name
        _ = context
    }

    public func addObserver(_ observer: @escaping @MainActor @Sendable (PolicyEvent) -> Void) -> UUID {
        let token = UUID()
        observers[token] = observer
        return token
    }

    public func removeObserver(_ token: UUID) {
        observers.removeValue(forKey: token)
    }

    public func register(_ provider: any PolicyProviding) {
        providers[provider.id] = provider
        if order.contains(provider.id) == false {
            order.append(provider.id)
        }
    }

    public func unregister(id: String) {
        providers.removeValue(forKey: id)
        order.removeAll { $0 == id }
    }

    private func orderedProviders() -> [any PolicyProviding] {
        order
            .compactMap { providers[$0] }
            .sorted { lhs, rhs in
                if lhs.kind != rhs.kind {
                    // core first
                    return lhs.kind == .core
                }
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.id < rhs.id
            }
    }

    public func decideNavigation(_ ctx: NavigationContext) async -> PolicyDecision {
        var merged = PolicyMutation()

        for provider in orderedProviders() {
            if let decision = await provider.decideNavigation(ctx) {
                notify(.init(domain: .navigation, providerID: provider.id, decision: decision))
                switch decision {
                case .allow:
                    continue
                case .cancel:
                    return decision
                case .modify(let mutation):
                    merged = merge(into: merged, mutation)
                }
            }
        }

        return merged.isEmpty ? .allow : .modify(merged)
    }

    public func decideResource(_ ctx: ResourceContext) async -> PolicyDecision {
        var merged = PolicyMutation()

        for provider in orderedProviders() {
            if let decision = await provider.decideResource(ctx) {
                notify(.init(domain: .resource, providerID: provider.id, decision: decision))
                switch decision {
                case .allow:
                    continue
                case .cancel:
                    return decision
                case .modify(let mutation):
                    merged = merge(into: merged, mutation)
                }
            }
        }

        return merged.isEmpty ? .allow : .modify(merged)
    }

    public func decidePrivacy(_ ctx: PrivacyContext) async -> PolicyDecision {
        for provider in orderedProviders() {
            if let decision = await provider.decidePrivacy(ctx) {
                notify(.init(domain: .privacy, providerID: provider.id, decision: decision))
                switch decision {
                case .allow:
                    continue
                case .cancel:
                    return decision
                case .modify:
                    // privacy mutations are currently ignored
                    continue
                }
            }
        }
        return .allow
    }

    private func merge(into base: PolicyMutation, _ next: PolicyMutation) -> PolicyMutation {
        var merged = base
        for (k, v) in next.headersToAdd { merged.headersToAdd[k] = v }
        merged.headersToRemove.formUnion(next.headersToRemove)
        if let ua = next.userAgentOverride { merged.userAgentOverride = ua }
        if let rp = next.referrerPolicyOverride { merged.referrerPolicyOverride = rp }
        return merged
    }

    private func notify(_ event: PolicyEvent) {
        guard observers.isEmpty == false else { return }
        for observer in observers.values {
            Task { @MainActor in
                observer(event)
            }
        }
    }
}
