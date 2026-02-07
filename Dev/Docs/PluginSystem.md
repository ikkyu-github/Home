# SafariLikeKit Plugin System

The plugin system allows extending SafariLikeKit functionality without modifying framework source code.

## Protocol Definition

```swift
@MainActor
public protocol BrowserPlugin: AnyObject {
    var pluginID: String { get }
    func onRegister(coordinator: Any)
    func onUnregister()
    func canHandle(url: URL) -> Bool
    func handle(url: URL) -> Bool
}
```

## Creating a Plugin

### Example: Custom Protocol Handler

```swift
@MainActor
public final class CustomProtocolPlugin: BrowserPlugin {
    public let pluginID = "com.example.custom-protocol"
    
    public func onRegister(coordinator: Any) {
        print("Plugin registered")
    }
    
    public func onUnregister() {
        print("Plugin unregistered")
    }
    
    public func canHandle(url: URL) -> Bool {
        url.scheme == "custom://"
    }
    
    public func handle(url: URL) -> Bool {
        guard canHandle(url: url) else { return false }
        
        // Custom handling logic
        let path = url.path
        print("Handling custom URL: \(path)")
        
        return true
    }
}
```

## Plugin Registration

```swift
// Create plugin manager
let pluginManager = PluginManagerImpl()

// Register plugin
let customPlugin = CustomProtocolPlugin()
pluginManager.register(customPlugin)

// Query plugins
if let plugin = pluginManager.plugin(by: "com.example.custom-protocol") {
    // Access plugin
}

// List all plugins
let allPlugins = pluginManager.allPlugins()

// Unregister when done
pluginManager.unregister("com.example.custom-protocol")
```

## Plugin Lifecycle

1. **Registration** - `onRegister(coordinator:)` called with coordinator reference
2. **Active** - Plugin receives URL handling requests via `canHandle()` and `handle()`
3. **Deregistration** - `onUnregister()` called for cleanup

## Best Practices

1. **Unique IDs** - Use reverse-domain notation: `com.company.feature`
2. **Error Handling** - Return `false` from `handle()` if processing fails
3. **Cleanup** - Release resources in `onUnregister()`
4. **Thread Safety** - All plugin methods marked `@MainActor`
5. **No Internal Access** - Plugins should only use public framework APIs

## Examples

### Example: Ad Blocker Plugin

```swift
@MainActor
public final class AdBlockerPlugin: BrowserPlugin {
    public let pluginID = "com.example.adblocker"
    
    private var blockedDomains = Set<String>()
    
    public init() {
        blockedDomains = ["ads.example.com", "tracking.example.com"]
    }
    
    public func onRegister(coordinator: Any) {
        // Initialize resources
    }
    
    public func onUnregister() {
        blockedDomains.removeAll()
    }
    
    public func canHandle(url: URL) -> Bool {
        if let host = url.host {
            return blockedDomains.contains(host)
        }
        return false
    }
    
    public func handle(url: URL) -> Bool {
        // Block navigation to ad domains
        return true
    }
}
```

### Example: Download Manager Plugin

```swift
@MainActor
public final class DownloadManagerPlugin: BrowserPlugin {
    public let pluginID = "com.example.download-manager"
    
    public func onRegister(coordinator: Any) {}
    public func onUnregister() {}
    
    public func canHandle(url: URL) -> Bool {
        // Handle downloads:// protocol
        return url.scheme == "downloads"
    }
    
    public func handle(url: URL) -> Bool {
        let action = url.host ?? ""
        switch action {
        case "show":
            // Show downloads UI
            return true
        case "clear":
            // Clear downloads
            return true
        default:
            return false
        }
    }
}
```

## Plugin Coordination

Plugins can coordinate with the browser:

```swift
// Pass coordinator for access to browser functionality
public func onRegister(coordinator: Any) {
    if let coord = coordinator as? BrowserCoordinator {
        // Access domain and UI state
        // Navigate, load URLs, etc.
    }
}
```

## Constraints

- Plugins cannot modify framework internals
- No access to `SplitBrowserViewModel` or `BrowserEnvironment`
- Limited to public API surface
- Plugin errors should not crash the browser

## Future Enhancements

- Plugin versioning and compatibility checks
- Plugin data persistence
- Plugin permission system
- Plugin marketplace/store
- Plugin communication system (plugin-to-plugin)
