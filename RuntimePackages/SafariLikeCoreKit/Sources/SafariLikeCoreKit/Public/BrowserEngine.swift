
import Foundation

/// Public role alias for runtime tabs managed by the browser engine.
public typealias TabRole = TabWebStore.Role

/// High-level interface for creating and managing tab engines.
///
/// Threading:
/// - ใช้ property/method ที่แตะ WebKit หรือ runtime engine จาก main actor เท่านั้น
///   (ดู `@MainActor` ที่ระดับ requirement ด้านล่าง).
/// - ตัว protocol เองไม่ได้ผูกกับ main actor หรือ Sendable ใด ๆ โดยตรง; เป็นเพียง
///   API contract ด้าน runtime เท่านั้น.
public protocol BrowserEngine {
    associatedtype Tab: TabEngine & TabLifecycle

    /// All tab identifiers that currently have a live runtime store.
    ///
    /// Threading: Read on the main actor.
    @MainActor
    var aliveTabIDs: [UUID] { get }

    /// Returns an already-created store if it is currently alive.
    ///
    /// Threading: Call on the main actor.
    @MainActor
    func existingStore(for tabID: UUID) -> Tab?

    /// Returns a runtime store for the tab, creating one if needed.
    ///
    /// Threading: Call on the main actor.
    @MainActor
    func store(for tabID: UUID, role: TabRole) async -> Tab

    /// Update the search engine URL for all managed tabs.
    ///
    /// Threading: Call on the main actor.
    @MainActor
    func updateSearchEngineURL(_ url: URL)
}

/// Default CoreKit implementation that backs the browser engine.
extension TabRegistry: BrowserEngine {
    public typealias Tab = TabWebStore
}
