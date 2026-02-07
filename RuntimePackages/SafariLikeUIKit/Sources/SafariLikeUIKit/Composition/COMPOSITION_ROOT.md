# SafariLikeUIKit Composition Root

## Overview

`SafariLikeUIKitFactory` is the **Composition Root** for the SafariLikeUIKit module. It centralizes the creation of all UI layer implementations and exposes them through protocol interfaces to decouple from concrete types.

## Architecture Principle

```
┌─────────────────────────────────────────┐
│  SafariLikeUIKitFactory                 │
│  (Composition Root)                     │
├─────────────────────────────────────────┤
│ Creates all implementations:             │
│  • TabThumbnailStore                    │
│  • WebsitePreferencesStore              │
│                                          │
│ Returns as protocols:                    │
│  • TabThumbnailProviding                │
│  • WebsitePreferencesProviding          │
└─────────────────────────────────────────┘
            ↓         ↓
    ┌──────────┐  ┌──────────┐
    │ App      │  │ SafariLK  │
    │ Consumes │  │ Consumes  │
    │ Protocols│  │ Protocols │
    └──────────┘  └──────────┘
```

## Benefits

### 1. **Decoupling**
- App/SafariLikeKit never directly instantiate `TabThumbnailStore` or `WebsitePreferencesStore`
- Consumers receive protocol instances only
- No tight coupling to UI layer implementations

### 2. **Testability**
- Easy to inject mock implementations for testing
- Mock can implement `TabThumbnailProviding` without needing UIKit/WebKit

### 3. **Maintainability**
- Single place to manage object lifetimes (singletons)
- Changes to implementations don't affect consumers
- Clear responsibility separation

### 4. **Scalability**
- Adding new implementations is straightforward
- All creation logic stays in factory
- Consumers remain unchanged

## Usage Example

### Scenario 1: Create Factory Once During App Launch

```swift
// AppDelegate or App.swift
class AppDelegate {
    let uiKitFactory = SafariLikeUIKitFactory()
    
    func application(_ application: UIApplication, 
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Factory is now available for the app lifetime
        return true
    }
}
```

### Scenario 2: Get Protocol-Based Implementations

```swift
// In your view model or controller
let factory = SafariLikeUIKitFactory()

// ✅ RECOMMENDED: Use protocols
let thumbnails: TabThumbnailProviding = factory.makeThumbnailProvider()
let preferences: WebsitePreferencesProviding = factory.makePreferencesProvider()

// Use via protocol interface (no need to know about TabThumbnailStore)
let data = thumbnails.thumbnailData(for: tabID)
thumbnails.setThumbnailData(newData, for: tabID)
```

### Scenario 3: Inject Into Environment

```swift
// SwiftUI view hierarchy
struct BrowserView: View {
    @EnvironmentObject var thumbnails: TabThumbnailProviding
    @EnvironmentObject var preferences: WebsitePreferencesProviding
    
    var body: some View {
        // Use protocol interface
        Image(uiImage: UIImage(data: thumbnails.thumbnailData(for: tabID) ?? Data()) ?? UIImage())
    }
}

// Setup in App.swift
@main
struct BrowserApp: App {
    let factory = SafariLikeUIKitFactory()
    
    var body: some Scene {
        WindowGroup {
            BrowserView()
                .environmentObject(factory.makeThumbnailProvider() as TabThumbnailProviding)
                .environmentObject(factory.makePreferencesProvider() as WebsitePreferencesProviding)
        }
    }
}
```

### Scenario 4: Only UIKit-Specific Code Uses Concrete Types

```swift
// Only inside SafariLikeUIKit itself or very close UI code
let factory = SafariLikeUIKitFactory()
let store = factory.makeThumbnailStore()  // Internal method - returns TabThumbnailStore

// Only here do we access UI-specific methods
store.capture(tabID: tabID, webView: webView)
let image = store.thumbnail(for: tabID)
```

## What's NOT Allowed

### ❌ Anti-Patterns (Don't Do This)

```swift
// ❌ WRONG: App creating implementations directly
let thumbnails = TabThumbnailStore()
let preferences = WebsitePreferencesStore()

// ❌ WRONG: SafariLikeKit creating UI implementations
func createBrowser() {
    let store = TabThumbnailStore()  // No! Use factory instead
}

// ❌ WRONG: Tight coupling to concrete types
func processThumbnails(_ store: TabThumbnailStore) {  // Should accept TabThumbnailProviding
    store.capture(tabID: id, webView: wv)
}
```

## Current Implementations

| Protocol | Implementation | Location | Purpose |
|----------|-----------------|----------|---------|
| `TabThumbnailProviding` | `TabThumbnailStore` | `Thumbnails/` | Tab screenshot cache |
| `WebsitePreferencesProviding` | `WebsitePreferencesStore` | `WebsitePreferences/` | Per-site preferences |

## Future Extensibility

When adding new implementations:

1. **Create the concrete class** (e.g., `BookmarkStore`) in SafariLikeUIKit
2. **Make it conform to a protocol** (e.g., `BookmarkProviding` in SafariLikeKit/Core)
3. **Add factory method** to `SafariLikeUIKitFactory`

```swift
// In SafariLikeUIKitFactory
private let bookmarkStoreInstance = BookmarkStore()

public func makeBookmarkProvider() -> BookmarkProviding {
    bookmarkStoreInstance
}
```

## Thread Safety

- All factory methods are `@MainActor`
- All created instances are `@MainActor`
- Safe to call from UIViewController, AppDelegate, or SwiftUI
- Instances are singletons and retained for app lifetime

## Testing

For unit tests, inject mock implementations:

```swift
struct MockThumbnailProvider: TabThumbnailProviding {
    var thumbnailData: [UUID: Data] = [:]
    
    func thumbnailData(for tabID: UUID) -> Data? {
        self.thumbnailData[tabID]
    }
    
    func setThumbnailData(_ data: Data?, for tabID: UUID) {
        self.thumbnailData[tabID] = data
    }
    
    func allThumbnails() -> [UUID: Data] {
        thumbnailData
    }
    
    func clearAllThumbnails() {
        thumbnailData.removeAll()
    }
}

// In your test
let mockProvider = MockThumbnailProvider()
let viewModel = BrowserViewModel(thumbnailProvider: mockProvider)
```

## Summary

✅ **SafariLikeUIKitFactory is the single source of truth for creating UI layer implementations**

✅ **Consumers never directly instantiate TabThumbnailStore or WebsitePreferencesStore**

✅ **All interactions happen through protocols (TabThumbnailProviding, WebsitePreferencesProviding)**

✅ **This enables loose coupling, easier testing, and cleaner architecture**
