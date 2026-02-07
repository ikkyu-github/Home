import Foundation
import SafariLikeContracts

// MARK: - Composition Root: SafariLikeUIKit Factory

/// Factory for creating all SafariLikeUIKit implementations.
///
/// **Purpose:**
/// This is the Composition Root for SafariLikeUIKit. It centralizes the creation of all
/// UI layer implementations (TabThumbnailStore, WebsitePreferencesStore, etc.) and exposes
/// them through protocol interfaces to decouple from concrete types.
///
/// **Reusability:**
/// SafariLikeUIKit is framework-independent and can be imported into any app:
/// - No app-specific hardcoded values
/// - All dependencies are injected via factory methods
/// - Configurable file storage (JSON, database, etc.)
/// - Works in single-window and multi-window environments
///
/// **Architecture Principle:**
/// - Only SafariLikeUIKitFactory creates UI layer implementations
/// - Consumers (App, SafariLikeKit) receive instances as protocols, not concrete classes
/// - Enables dependency injection without tight coupling
/// - Makes testing easier (can inject mock implementations)
///
/// **Usage Example:**
/// ```swift
/// // Works in any app (webOS, MyBrowser, SomeOtherBrowser, etc.)
/// let factory = SafariLikeUIKitFactory(thumbnailStoreProvider: SafariLikeKit.TabThumbnailStore())
/// let thumbnailProvider = factory.makeThumbnailProvider()
/// let preferencesProvider = factory.makePreferencesProvider()
/// ```
///
/// **Thread Safety:**
/// All created instances are @MainActor. Factory methods are safe to call from any thread
/// (they immediately hop to @MainActor for initialization).
///
/// **Future Enhancements:**
/// - TODO: Plugin system for extensible providers (bookmarks, history, downloads)
/// - TODO: Multi-window support - allow multiple factory instances per window/scene
/// - TODO: Custom storage backends (not just JSONFileStoreActor)
@MainActor
public final class SafariLikeUIKitFactory {
    
    // MARK: - Shared Instances (Singletons)
    
    private let thumbnailStoreProvider: any ThumbnailStoreProviding
    
    /// Singleton WebsitePreferencesStore instance for the app lifetime.
    ///
    /// Thread safety: Lazy-initialized, safe for concurrent access.
    private let preferencesStoreInstance = WebsitePreferencesStore()
    
    // MARK: - Initialization
    
    /// Creates a new factory instance.
    ///
    /// Typically, your app creates one factory during startup and reuses it.
    /// This is normally injected into the environment or stored in a parent container.
    ///
    /// **Multi-Window Scenario:**
    /// For multi-window apps, you can create a separate factory per window/scene:
    /// ```swift
    /// // In SceneDelegate or WindowGroup
    /// let factoryPerWindow = SafariLikeUIKitFactory(thumbnailStoreProvider: SafariLikeKit.TabThumbnailStore())
    /// ```
    ///
    /// **Singleton vs. Per-Window:**
    /// - Single app/window: Create one factory, reuse throughout app lifetime
    /// - Multi-window: Consider creating one factory per SceneSession/UIWindowScene
    /// - Testing: Create fresh factory instances for each test
    @available(*, unavailable, message: "Inject services from the composition root. SafariLikeUIKit must not create runtime/core objects.")
    public init() {
        fatalError("unavailable")
    }

    public init(thumbnailStoreProvider: any ThumbnailStoreProviding) {
        self.thumbnailStoreProvider = thumbnailStoreProvider
    }
    
    // MARK: - Public Factory Methods: TabThumbnail
    
    /// Creates or returns the shared TabThumbnailStore implementation.
    ///
    /// **Returns:** The singleton TabThumbnailStore instance, exposed as TabThumbnailProviding protocol.
    ///
    /// **Semantics:**
    /// - Multiple calls return the same instance
    /// - Instance is retained for the app lifetime
    /// - Safe for concurrent access (all @MainActor)
    ///
    /// **Usage:**
    /// ```swift
    /// let provider = factory.makeThumbnailProvider()
    /// let data = provider.thumbnailData(for: tabID)
    /// ```
    public func makeThumbnailProvider() -> TabThumbnailProviding {
        thumbnailStoreProvider.makeThumbnailProvider()
    }
    
    // MARK: - Public Factory Methods: WebsitePreferences
    
    /// Creates or returns the shared WebsitePreferencesStore implementation.
    ///
    /// **Returns:** The singleton WebsitePreferencesStore instance, exposed as WebsitePreferencesProviding protocol.
    ///
    /// **Semantics:**
    /// - Multiple calls return the same instance
    /// - Instance is retained for the app lifetime
    /// - Safe for concurrent access (all @MainActor)
    ///
    /// **Usage:**
    /// ```swift
    /// let provider = factory.makePreferencesProvider()
    /// let prefs = provider.getPreferences(for: domain)
    /// ```
    public func makePreferencesProvider() -> WebsitePreferencesProviding {
        preferencesStoreInstance
    }
    
    /// Creates or returns the shared WebsitePreferencesStore as a concrete class.
    ///
    /// **Warning:** Only use this if you need UIKit-specific methods (e.g., `applyPreferences(to:)`).
    /// New code should prefer `makePreferencesProvider()` for protocol decoupling.
    ///
    /// **Returns:** The singleton WebsitePreferencesStore instance with full UIKit API access.
    ///
    /// **Thread Safety:** Safe to call on @MainActor.
    internal func makePreferencesStore() -> WebsitePreferencesStore {
        preferencesStoreInstance
    }
}

// MARK: - TODO: Plugin System

/// **Future Enhancement - Plugin System:**
///
/// The factory is designed to support extensible providers through plugins.
/// When implemented, the architecture will look like:
///
/// ```swift
/// public protocol UIKitProviderPlugin {
///     associatedtype Provider
///     func makeProvider() -> Provider
/// }
///
/// // Plugins for additional functionality
/// public protocol BookmarkProviderPlugin: UIKitProviderPlugin
///     where Provider: BookmarkProviding { }
///
/// public protocol HistoryProviderPlugin: UIKitProviderPlugin
///     where Provider: HistoryProviding { }
///
/// public protocol DownloadProviderPlugin: UIKitProviderPlugin
///     where Provider: DownloadProviding { }
///
/// // Factory extension
/// extension SafariLikeUIKitFactory {
///     public func register<P: UIKitProviderPlugin>(_ plugin: P) {
///         // Cache and manage plugin instances
///     }
/// }
/// ```
///
/// **Benefits:**
/// - Apps can extend SafariLikeUIKit with custom providers
/// - Plugins are lazily-loaded, independent modules
/// - Plugins use same protocol-based architecture
/// - Easy to test with mock plugins

// MARK: - TODO: Multi-Window Support

/// **Future Enhancement - Multi-Window Support:**
///
/// Currently, SafariLikeUIKitFactory uses single instance per app.
/// Future version should support per-window/scene factories:
///
/// ```swift
/// // Register factory per UIWindowScene
/// @main
/// struct MyBrowserApp: App {
///     @Environment(\.scenePhase) var scenePhase
///
///     var body: some Scene {
///         WindowGroup {
///             // Each window gets its own factory instance
///             BrowserView()
///                 .onAppear {
///                     let windowFactory = SafariLikeUIKitFactory(thumbnailStoreProvider: SafariLikeKit.TabThumbnailStore())
///                     // Use window-specific factory
///                 }
///         }
///     }
/// }
/// ```
///
/// **Benefits:**
/// - Each window maintains independent thumbnail cache
/// - Each window has independent website preferences
/// - Multi-window apps get proper memory isolation
/// - Tabs can't leak between windows
///
/// **Implementation Strategy:**
/// - Create WindowGroup protocol for window context
/// - Pass windowID to factory initialization
/// - Store per-window instances in NSMapTable
/// - Clean up when window closes

// MARK: - Preview Support

extension SafariLikeUIKitFactory {
    /// Factory instance for SwiftUI previews.
    ///
    /// Creates fresh instances (not singletons) for each preview.
    static let preview: SafariLikeUIKitFactory = {
        SafariLikeUIKitFactory(thumbnailStoreProvider: PreviewThumbnailStoreProvider())
    }()
}

@MainActor
private final class PreviewThumbnailStoreProvider: ThumbnailStoreProviding, TabThumbnailProviding {
    private var encodedStore: [UUID: Data] = [:]

    func makeThumbnailProvider() -> any TabThumbnailProviding {
        self
    }

    func thumbnailData(for tabID: UUID) -> Data? {
        encodedStore[tabID]
    }

    func setThumbnailData(_ data: Data?, for tabID: UUID) {
        encodedStore[tabID] = data
    }
}
