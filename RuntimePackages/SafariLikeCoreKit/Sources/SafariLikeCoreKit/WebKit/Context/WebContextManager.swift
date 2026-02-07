import Foundation
import WebKit

@MainActor
public final class WebContextManager {
    public struct Key: Hashable, Sendable {
        public let windowID: String
        public let paneID: String
        public let tabID: UUID
        public let privacyMode: WebPrivacyMode

        public init(windowID: String, paneID: String, tabID: UUID, privacyMode: WebPrivacyMode) {
            self.windowID = windowID
            self.paneID = paneID
            self.tabID = tabID
            self.privacyMode = privacyMode
        }
    }

    private var contexts: [Key: WebContext] = [:]

    /// Optional per-window hook for mutating a freshly created `WKWebViewConfiguration`.
    ///
    /// This is intended for higher layers to apply WebView-bound features (e.g. resource plugins)
    /// **only at configuration creation time**, not per navigation.
    private var configurationCustomizersByWindowID: [String: (@MainActor (WKWebViewConfiguration) -> Void)] = [:]

    public struct IsolatedKey: Hashable, Sendable {
        public let windowID: String
        public let paneID: String
        public let tabID: UUID
        public let privacyMode: WebPrivacyMode
        public let siteKey: String

        public init(windowID: String, paneID: String, tabID: UUID, privacyMode: WebPrivacyMode, siteKey: String) {
            self.windowID = windowID
            self.paneID = paneID
            self.tabID = tabID
            self.privacyMode = privacyMode
            self.siteKey = siteKey
        }
    }

    private var isolatedContexts: [IsolatedKey: WebContext] = [:]
    private var isolatedLRUByPane: [Key: [String]] = [:]

    public init() {}

    /// Register (or clear) a per-window configuration customizer.
    ///
    /// - Important: Callers should clear this when a window/session is torn down
    ///   to avoid retaining window-scoped objects.
    public func setConfigurationCustomizer(
        for windowID: String,
        customizer: (@MainActor (WKWebViewConfiguration) -> Void)?
    ) {
        if let customizer {
            configurationCustomizersByWindowID[windowID] = customizer
        } else {
            configurationCustomizersByWindowID.removeValue(forKey: windowID)
        }
    }

    public func context(windowID: String, paneID: String, tabID: UUID, privacyMode: WebPrivacyMode) -> WebContext {
        let key = Key(windowID: windowID, paneID: paneID, tabID: tabID, privacyMode: privacyMode)
        if let existing = contexts[key] {
            return existing
        }
        let created = WebContext(
            privacyMode: privacyMode,
            configurationCustomizer: configurationCustomizersByWindowID[windowID]
        )
        contexts[key] = created
        return created
    }

    public func context(
        windowID: String,
        paneID: String,
        tabID: UUID,
        privacyMode: WebPrivacyMode,
        route: WebContextRoute,
        maxIsolatedPerPane: Int = 2
    ) -> WebContext {
        switch route {
        case .paneDefault:
            return context(windowID: windowID, paneID: paneID, tabID: tabID, privacyMode: .regular)
        case .panePrivate:
            return context(windowID: windowID, paneID: paneID, tabID: tabID, privacyMode: .private)
        case .isolated(let siteKey, let mode):
            return isolatedContext(
                windowID: windowID,
                paneID: paneID,
                tabID: tabID,
                privacyMode: mode,
                siteKey: siteKey,
                maxIsolatedPerPane: maxIsolatedPerPane
            )
        }
    }

    public func isolatedContext(
        windowID: String,
        paneID: String,
        tabID: UUID,
        privacyMode: WebPrivacyMode,
        siteKey: String,
        maxIsolatedPerPane: Int = 2
    ) -> WebContext {
        let paneKey = Key(windowID: windowID, paneID: paneID, tabID: tabID, privacyMode: privacyMode)
        let key = IsolatedKey(windowID: windowID, paneID: paneID, tabID: tabID, privacyMode: privacyMode, siteKey: siteKey)
        if let existing = isolatedContexts[key] {
            touchIsolated(siteKey: siteKey, paneKey: paneKey)
            return existing
        }

        evictIsolatedIfNeeded(paneKey: paneKey, maxIsolatedPerPane: maxIsolatedPerPane)

        let created = WebContext(
            privacyMode: privacyMode,
            configurationCustomizer: configurationCustomizersByWindowID[windowID]
        )
        isolatedContexts[key] = created
        touchIsolated(siteKey: siteKey, paneKey: paneKey)
        return created
    }

    public func recreateContext(windowID: String, paneID: String, tabID: UUID, privacyMode: WebPrivacyMode) -> WebContext {
        let key = Key(windowID: windowID, paneID: paneID, tabID: tabID, privacyMode: privacyMode)
        let created = WebContext(
            privacyMode: privacyMode,
            configurationCustomizer: configurationCustomizersByWindowID[windowID]
        )
        contexts[key] = created
        return created
    }

    public func tearDownContext(windowID: String, paneID: String, tabID: UUID) {
        contexts.keys
            .filter { $0.windowID == windowID && $0.paneID == paneID && $0.tabID == tabID }
            .forEach { contexts[$0] = nil }

        isolatedContexts.keys
            .filter { $0.windowID == windowID && $0.paneID == paneID && $0.tabID == tabID }
            .forEach { isolatedContexts[$0] = nil }

        isolatedLRUByPane.keys
            .filter { $0.windowID == windowID && $0.paneID == paneID && $0.tabID == tabID }
            .forEach { isolatedLRUByPane[$0] = nil }
    }

    public func tearDownContext(windowID: String, paneID: String) {
        contexts.keys
            .filter { $0.windowID == windowID && $0.paneID == paneID }
            .forEach { contexts[$0] = nil }

        isolatedContexts.keys
            .filter { $0.windowID == windowID && $0.paneID == paneID }
            .forEach { isolatedContexts[$0] = nil }

        isolatedLRUByPane.keys
            .filter { $0.windowID == windowID && $0.paneID == paneID }
            .forEach { isolatedLRUByPane[$0] = nil }
    }

    public func tearDownWindow(windowID: String) {
        contexts.keys
            .filter { $0.windowID == windowID }
            .forEach { contexts[$0] = nil }

        isolatedContexts.keys
            .filter { $0.windowID == windowID }
            .forEach { isolatedContexts[$0] = nil }

        isolatedLRUByPane.keys
            .filter { $0.windowID == windowID }
            .forEach { isolatedLRUByPane[$0] = nil }

        configurationCustomizersByWindowID.removeValue(forKey: windowID)
    }

    private func touchIsolated(siteKey: String, paneKey: Key) {
        var list = isolatedLRUByPane[paneKey] ?? []
        list.removeAll { $0 == siteKey }
        list.insert(siteKey, at: list.startIndex)
        isolatedLRUByPane[paneKey] = list
    }

    private func evictIsolatedIfNeeded(paneKey: Key, maxIsolatedPerPane: Int) {
        let cap = max(1, maxIsolatedPerPane)
        let list = isolatedLRUByPane[paneKey] ?? []
        if list.count < cap { return }
        if let lruSite = list.last {
            let victim = IsolatedKey(
                windowID: paneKey.windowID,
                paneID: paneKey.paneID,
                tabID: paneKey.tabID,
                privacyMode: paneKey.privacyMode,
                siteKey: lruSite
            )
            isolatedContexts[victim] = nil
            isolatedLRUByPane[paneKey]?.removeAll { $0 == lruSite }
        }
    }
}
