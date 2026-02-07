#if DEBUG
import Foundation

public extension BrowserSessionStore {
    /// In-memory session store for SwiftUI previews and UI smoke tests.
    static var preview: BrowserSessionStore {
        let store = BrowserSessionStore(persistence: .memory)

        // Seed with a couple of tabs so UI isn't empty.
        if store.tabs.isEmpty {
            _ = store.addTab()
            _ = store.addTab()
        }
        return store
    }
}
#endif
