import Foundation
import SafariLikeContracts
import SafariLikeCoreKit
@MainActor
enum CoreStoreFactory {
    /// Low-level factory for creating a session store with an explicit
    /// filename. Prefer the higher-level helpers (e.g. makeWindowSessionStore)
    /// when working with multi-window setups so each window gets its own
    /// persisted session.
    static func makeSessionStore(filename: String) -> BrowserSessionStore {
        BrowserSessionStore(persistence: .disk(filename: filename))
    }
    /// Create a session store for a specific logical window/scene.
    ///
    /// This helper ensures each window gets its own JSON file so tab order
    /// and the active tab are restored deterministically per window.
    /// The caller is responsible for providing a stable scene identifier
    /// (typically UISceneSession.persistentIdentifier).
    static func makeWindowSessionStore(sceneID: String) -> BrowserSessionStore {
        BrowserSessionStore(
            persistence: .sceneBucket(
                sceneID: sceneID,
                legacyFilename: "session_\(sceneID).json"
            )
        )
    }
    /// Create a session store for a specific browser window.
    ///
    /// Prefer this overload when you have a stable `BrowserWindow` identity
    /// (UUID) that should map 1:1 with a persisted tab stack.
    static func makeWindowSessionStore(windowID: UUID) -> BrowserSessionStore {
        let legacy = "session_window_\(windowID.uuidString).json"
        // Bucket ID is derived from the stable window UUID to preserve per-window restore.
        let bucketID = "window_\(windowID.uuidString)"
        return BrowserSessionStore(
            persistence: .sceneBucket(
                sceneID: bucketID,
                legacyFilename: legacy
            )
        )
    }
    /// Core-default implementation of WebsitePreferencesProviding.
    ///
    /// UIKit apps using SafariLikeUIKit should inject their own
    /// WebsitePreferencesStore implementation instead of relying
    /// on this factory. This keeps SafariLikeKit free of UIKit
    /// while still providing working behavior in pure-SwiftUI
    /// contexts.
    static func makeWebsitePreferencesStore() -> WebsitePreferencesProviding {
        DefaultWebsitePreferencesStore()
    }

    static func makeWebsiteDataService() -> any WebsiteDataServicing {
        WebKitWebsiteDataService()
    }

    static func makeAutofillStatusService() -> AutofillStatusService {
        AutofillStatusService(checker: AppleAutofillSystemChecker())
    }

    static func makeUserScriptStore() -> UserScriptStore {
        let persistence = UserScriptsDiskPersistence(filename: "user_scripts.json")
        let store = UserScriptStore(persistence: persistence)
        Task {
            await store.bootstrap()
        }
        return store
    }
}
