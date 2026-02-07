# SafariLikeKit Framework

A production-grade Safari-like browser framework for iOS/macOS, featuring split-pane layouts, tab management, web customization, and a plugin architecture.

## Quick Start

### Installation

```swift
// In your app's main Scene
let (hostingVC, session) = SafariLikeUIKitHost.makeHostingController(
    sceneID: "main",
    initialURL: "https://example.com",
    configuration: .default
)

// Add to your view hierarchy
addChild(hostingVC)
view.addSubview(hostingVC.view)
```

## Public API Surface

### Core Types

- **`BrowserSceneSession`**: Main public facade. Manages a single browser session.
- **`SafariLikeBrowserView`**: SwiftUI wrapper for embedding browser in SwiftUI apps.
- **`SafariLikeConfiguration`**: Configuration object with sensible defaults.
- **`SafariLikeFactory`**: Factory enum for creating properly initialized sessions.

### Stores (Observable)

- **`BookmarkStore`**: Manages bookmarks (observable).
- **`HistoryStore`**: Manages browsing history (observable).
- **`ReadingListStore`**: Manages reading list items (observable).
- **`DownloadStore`**: Manages file downloads (observable).

### Models

- **`TabInfo`**: Public facade for tab information (id, title, urlString).
- **`BrowserTab`**: Core tab model from BrowserCore.
- **`ChromePolicy`**: Configuration for chrome UI behavior.

## Framework Boundary

### Public (Framework Surface)

- Types marked `public` in `SafariLikeKit/Public/` and main files
- Facade patterns for internal state
- Configuration and factory patterns

### Internal (Implementation Engine)

- OS simulation layer: `ProcessManager`, `VirtualFileSystem`, `ServiceBus`
- View models and state management
- Runtime controllers and registries
- All marked `internal` or `private`

## Architecture Layers

### 1. Domain Layer (`SafariLikeKit/Core/DomainState.swift`)

- Business logic and data models
- Tab management, session state
- No UI concerns

### 2. UI Layer (`SafariLikeKit/Core/UIState.swift`)

- Presentation state (visibility, animations, progress)
- SwiftUI/UIKit view state

### 3. Coordinator Layer (`SafariLikeKit/Core/Coordinator.swift`)

- Orchestrates actions between Domain and UI
- Handles navigation and user interactions

## Plugin System

SafariLikeKit supports extensibility through plugins:

```swift
public protocol BrowserPlugin {
    var pluginID: String { get }
    func onRegister(coordinator: Any)
    func canHandle(url: URL) -> Bool
    func handle(url: URL) -> Bool
}

// Register a plugin
let pluginManager = PluginManagerImpl()
pluginManager.register(MyCustomPlugin())
```

### Plugin Capabilities

- Handle custom URL schemes
- Lifecycle hooks (register, unregister)
- Access coordinator for navigation

## Configuration

```swift
let config = SafariLikeConfiguration(
    defaultHomeURL: "https://example.com",
    maxAliveWebViews: 5,
    contentBlockerEnabled: true,
    searchEngineURL: "https://www.google.com/search?q={query}"
)
```

## State Management

### Observable Stores

- All stores conform to `ObservableObject`
- Use `@ObservedObject` in SwiftUI views
- Changes trigger view updates automatically

### Session Persistence

```swift
session.persistSessionNow()  // Save before backgrounding
session.invalidateSession()  // Clear all tabs
```

## Threading

All public APIs are marked `@MainActor` for thread safety:

```swift
@MainActor
public final class BrowserSceneSession { ... }
```

Safe to call from any thread; execution marshaled to main thread.

## Best Practices

1. **Always use public facades** - Don't import internal types
2. **Observe stores** - Use `@ObservedObject` for reactive updates
3. **Handle nil states** - Check `activeStore` for navigation
4. **Persist on backgrounding** - Call `persistSessionNow()` in `sceneDidEnterBackground`
5. **Clean up sessions** - Call `invalidateSession()` when scene disconnects

## Troubleshooting

### "No active tab" message

- This is normal. Use `BrowserSceneSession.newTab()` to add tabs.
- Empty state shows `EmptyBrowserPane` automatically.

### Web view not loading

- Check that URLs have proper schemes (http://, https://)
- Verify search engine configuration for fallback queries

### App crashes on session access

- Always guard optional `activeStore`: `guard let store = session.activeStore`
- Empty state UI shown when no tabs present

## Migration Guide

### From SafariUI v2 to SafariLikeKit

1. Replace `SafariUIViewController` with `SafariLikeUIKitHost`
2. Use `BrowserSceneSession` instead of direct model access
3. Update store observations to use `@ObservedObject`
4. Migrate bookmarks/history to public `Store` interfaces

## License

See LICENSE file in repository root.
