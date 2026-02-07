import Foundation

/// Pure decision policy for tab resource management.
///
/// This type makes the *only* decisions about whether tabs should stay active,
/// be frozen (detach WebKit but keep runtime metadata), or be evicted (destroy runtime).
public struct TabResourcePolicy: Sendable {
    public enum MemoryPressureLevel: String, Sendable {
        case none
        case warning
        case critical
    }

    public enum Action: String, Sendable {
        case stayActive
        case freeze
        case evict
    }

    public struct TabDescriptor: Sendable {
        public let id: UUID
        public let isProtected: Bool
        public let isActive: Bool
        public let isInSession: Bool
        public let hasLiveWebView: Bool
        public let lastActiveAt: Date?

        public init(
            id: UUID,
            isProtected: Bool,
            isActive: Bool,
            isInSession: Bool,
            hasLiveWebView: Bool,
            lastActiveAt: Date?
        ) {
            self.id = id
            self.isProtected = isProtected
            self.isActive = isActive
            self.isInSession = isInSession
            self.hasLiveWebView = hasLiveWebView
            self.lastActiveAt = lastActiveAt
        }
    }

    public struct Input: Sendable {
        public let memoryPressureLevel: MemoryPressureLevel
        public let visiblePanesCount: Int
        public let activeTabCount: Int
        public let tabs: [TabDescriptor]

        /// Whether any enabled plugin is WebView-bound (e.g. content scripts / blockers).
        ///
        /// When true, the policy should be more conservative about detaching web views,
        /// because WebView-bound plugins are applied at configuration time and may need
        /// additional orchestration on re-creation.
        public let hasWebViewBoundPluginsEnabled: Bool

        /// Optional time-based discard support (used by periodic sweeps).
        public let now: Date?
        public let discardInactiveAfter: TimeInterval?

        public init(
            memoryPressureLevel: MemoryPressureLevel,
            visiblePanesCount: Int,
            activeTabCount: Int,
            tabs: [TabDescriptor],
            hasWebViewBoundPluginsEnabled: Bool = false,
            now: Date? = nil,
            discardInactiveAfter: TimeInterval? = nil
        ) {
            self.memoryPressureLevel = memoryPressureLevel
            self.visiblePanesCount = visiblePanesCount
            self.activeTabCount = activeTabCount
            self.tabs = tabs
            self.hasWebViewBoundPluginsEnabled = hasWebViewBoundPluginsEnabled
            self.now = now
            self.discardInactiveAfter = discardInactiveAfter
        }
    }

    public struct Decision: Sendable {
        public let actionsByTabID: [UUID: Action]

        public init(actionsByTabID: [UUID: Action]) {
            self.actionsByTabID = actionsByTabID
        }

        public var stayActive: [UUID] {
            actionsByTabID.compactMap { $0.value == .stayActive ? $0.key : nil }
        }

        public var freeze: [UUID] {
            actionsByTabID.compactMap { $0.value == .freeze ? $0.key : nil }
        }

        public var evict: [UUID] {
            actionsByTabID.compactMap { $0.value == .evict ? $0.key : nil }
        }
    }

    public init() {}

    public func decide(_ input: Input) -> Decision {
        var actions: [UUID: Action] = [:]

        func setAction(_ action: Action, for tab: TabDescriptor) {
            actions[tab.id] = action
        }

        // 1) Always keep protected/active tabs.
        for tab in input.tabs {
            if tab.isProtected || tab.isActive {
                setAction(.stayActive, for: tab)
            }
        }

        // 2) Evict anything that is no longer in the session but still has a live WebView.
        //    (This is a cleanup rule, independent of pressure.)
        for tab in input.tabs where tab.hasLiveWebView {
            guard tab.isInSession == false else { continue }
            guard tab.isProtected == false else { continue }
            guard tab.isActive == false else { continue }
            setAction(.evict, for: tab)
        }

        // 3) Memory pressure decision.
        switch input.memoryPressureLevel {
        case .critical:
            for tab in input.tabs where tab.hasLiveWebView {
                guard actions[tab.id] == nil else { continue }
                setAction(.evict, for: tab)
            }
        case .warning:
            if input.hasWebViewBoundPluginsEnabled {
                // Be more conservative: prefer keeping existing WebViews alive so
                // WebView-bound plugin application remains stable.
                for tab in input.tabs {
                    guard actions[tab.id] == nil else { continue }
                    setAction(.stayActive, for: tab)
                }
            } else {
                for tab in input.tabs where tab.hasLiveWebView {
                    guard actions[tab.id] == nil else { continue }
                    setAction(.freeze, for: tab)
                }
            }
        case .none:
            break
        }

        // 4) Time-based discard (only when not under memory pressure).
        if input.memoryPressureLevel == .none,
           let now = input.now,
           let discardAfter = input.discardInactiveAfter {
            for tab in input.tabs where tab.hasLiveWebView {
                guard actions[tab.id] == nil else { continue }
                guard tab.isProtected == false else { continue }
                guard tab.isActive == false else { continue }
                let lastActive = tab.lastActiveAt ?? .distantPast
                let inactiveFor = now.timeIntervalSince(lastActive)
                if inactiveFor >= discardAfter {
                    setAction(.evict, for: tab)
                } else {
                    setAction(.stayActive, for: tab)
                }
            }
        }

        // 5) Default: stay active (no-op) for any tab not explicitly decided.
        for tab in input.tabs {
            if actions[tab.id] == nil {
                setAction(.stayActive, for: tab)
            }
        }

        return Decision(actionsByTabID: actions)
    }
}
