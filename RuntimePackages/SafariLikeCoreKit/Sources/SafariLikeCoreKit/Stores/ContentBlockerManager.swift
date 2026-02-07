
import Foundation
import Combine
import os


// MARK: - Core Layer: Content Blocking State Management

/// Safari-grade content blocking configuration manager.
///
/// **Architecture:**
/// - Implements ContentBlockingProviding protocol (platform-independent)
/// - Manages state for ad, tracker, social, and privacy blocking
/// - Thread-safe @MainActor isolation
///
/// **Threading:** This manager is main-actor isolated.
/// All APIs must be called from the main actor.
@MainActor
public final class ContentBlockerManager: ObservableObject, ContentBlockingProviding {
        public private(set) var enabledLists: [ContentBlockerList] = [.ads, .trackers]
        public private(set) var isEnabled: Bool = true
        public private(set) var isReady: Bool = true
        public var onEnabledListsChanged: (([ContentBlockerList]) -> Void)?

        public init() {}

        public func setEnabled(_ enabled: Bool) {
                isEnabled = enabled
        }

        public func setListEnabled(_ list: ContentBlockerList, enabled: Bool) {
                if enabled {
                        if !enabledLists.contains(list) { enabledLists.append(list) }
                } else {
                        enabledLists.removeAll { $0 == list }
                }
                onEnabledListsChanged?(enabledLists)
        }
}
