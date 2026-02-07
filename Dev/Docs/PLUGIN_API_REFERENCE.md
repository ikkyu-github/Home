# Plugin System API Reference

## PluginHost

### Overview
`@MainActor` class that manages plugin lifecycle per window/scene.

**Location:** `SafariLikeKit/Plugins/Runtime/PluginHost.swift`

### Initialization

```swift
@MainActor
final class PluginHost {
    let windowID: UUID
    let tabID: UUID
    
    init(windowID: UUID, tabID: UUID, enablementStore: PluginEnablementStore)
}
```

### Methods

#### `getOrCreatePluginManager(for tabID: UUID) -> NextGenPluginManager`
Gets or creates a plugin manager for a specific tab.

```swift
let manager = await pluginHost.getOrCreatePluginManager(for: tabID)
// Returns the manager for this tab, creating it if needed
```

#### `getPluginManager(for tabID: UUID) -> NextGenPluginManager?`
Gets an existing plugin manager for a tab, or nil if not created.

```swift
if let manager = await pluginHost.getPluginManager(for: tabID) {
    let plugins = manager.getRegisteredPlugins()
}
```

#### `loadInstalledPlugins() async`
Discovers plugins in `~/Documents/Plugins/` and registers enabled ones.

```swift
// Called automatically from TabManager.init, but can be called again
await pluginHost.loadInstalledPlugins()
```

**What it does:**
1. Scans `~/Documents/Plugins/` directory
2. Loads `manifest.json` from each plugin directory
3. Checks `PluginEnablementStore` to see which are enabled
4. Calls `NextGenPluginManager.registerPlugin()` for enabled plugins

#### `registerEnabledPlugins() async`
Explicitly registers all enabled plugins.

```swift
// Register all enabled plugins (useful for refreshing)
await pluginHost.registerEnabledPlugins()
```

#### `enablePlugin(id: String) async`
Enables a plugin and registers it immediately.

```swift
await pluginHost.enablePlugin(id: "com.example.plugin")
// Result:
// 1. Saved to enabled_plugins.json
// 2. Plugin registered with NextGenPluginManager
```

#### `disablePlugin(id: String) async`
Disables a plugin and unloads it.

```swift
await pluginHost.disablePlugin(id: "com.example.plugin")
// Result:
// 1. Removed from enabled_plugins.json
// 2. Plugin unloaded from NextGenPluginManager
```

#### `shutdown()`
Cleans up plugin managers when scene/window closes.

```swift
pluginHost.shutdown()
// Removes all plugin manager instances
```

---

## PluginEnablementStore

### Overview
`actor` that persists enabled/disabled plugin state to JSON.

**Location:** `SafariLikeKit/Plugins/Runtime/PluginEnablementStore.swift`

**Storage:** `~/Documents/enabled_plugins.json`

### Initialization

```swift
actor PluginEnablementStore {
    init()
    // Automatically loads enabled_plugins.json from disk
}
```

### Methods

#### `isEnabled(pluginID: String) -> Bool`
Checks if a plugin is enabled.

```swift
let enabled = await enablementStore.isEnabled(pluginID: "com.example.plugin")
if enabled {
    print("Plugin is enabled")
}
```

#### `enable(pluginID: String)`
Enables a plugin and saves the state.

```swift
await enablementStore.enable(pluginID: "com.example.plugin")
// Writes to ~/Documents/enabled_plugins.json
```

#### `disable(pluginID: String)`
Disables a plugin and saves the state.

```swift
await enablementStore.disable(pluginID: "com.example.plugin")
// Updates ~/Documents/enabled_plugins.json
```

#### `getEnabledPlugins() -> [String]`
Gets all enabled plugin IDs.

```swift
let enabledIDs = await enablementStore.getEnabledPlugins()
for id in enabledIDs {
    print("Enabled: \(id)")
}
```

#### `reset()`
Clears all plugin enablement state.

```swift
await enablementStore.reset()
// Clears ~/Documents/enabled_plugins.json
```

---

## NextGenPluginManager

### Overview
`@MainActor` class that manages plugins for a specific tab.

**Location:** `SafariLikeKit/Plugins/Runtime/PluginHost.swift` (currently a stub)

### Initialization

```swift
@MainActor
class NextGenPluginManager {
    let windowID: UUID
    let tabID: UUID
    
    init(windowID: UUID, tabID: UUID)
}
```

### Methods

#### `registerPlugin(_ manifest: PluginManifest) async`
Registers a plugin by its manifest.

```swift
await pluginManager.registerPlugin(manifest)
// Stores plugin and prepares it for use
```

#### `getRegisteredPlugins() -> [PluginManifest]`
Gets all registered plugins for this tab.

```swift
let plugins = pluginManager.getRegisteredPlugins()
for plugin in plugins {
    print("\(plugin.name) v\(plugin.version)")
}
```

---

## PluginManifest

### Overview
Struct representing a plugin's metadata.

### Structure

```swift
struct PluginManifest: Codable {
    let id: String                  // e.g., "com.example.plugin"
    let name: String                // Display name
    let version: String             // Version string
    let entryPoint: String          // Main file path
    let permissions: [String]?      // Required capabilities
}
```

### Example

```json
{
  "id": "com.example.dark-mode",
  "name": "Dark Mode",
  "version": "1.0.0",
  "entryPoint": "plugin.js",
  "permissions": ["webview", "storage"]
}
```

---

## NavigationService Integration

### Overview
NavigationService can now access plugins through PluginHost.

### Initialization

```swift
init(
    tabManager: TabManager,
    pluginManager: NextGenPluginManager? = nil,
    pluginHost: PluginHost? = nil
)
```

### Usage

```swift
func loadURLString(_ urlString: String, force: Bool = false) {
    // Access plugins if available
    if let pluginHost = pluginHost {
        let manager = pluginHost.getPluginManager(for: pluginHost.tabID)
        // Notify plugins about navigation
    }
    
    // Continue with navigation...
}
```

---

## TabManager Integration

### Overview
TabManager automatically creates and manages PluginHost.

### Key Points

```swift
@MainActor
final class TabManager: ObservableObject {
    private let enablementStore = PluginEnablementStore()
    private(set) var pluginHost: PluginHost?
    
    init(...) {
        // Create PluginHost
        self.pluginHost = PluginHost(
            windowID: UUID(),
            tabID: initialActiveTabID,
            enablementStore: enablementStore
        )
        
        // Load plugins asynchronously
        Task { @MainActor [weak self] in
            await self?.pluginHost?.loadInstalledPlugins()
        }
    }
}
```

### Access from Views

```swift
@MainActor
struct SettingsView: View {
    @ObservedObject var tabManager: TabManager
    
    var body: some View {
        VStack {
            Button("Enable Plugin") {
                Task { @MainActor in
                    await tabManager.pluginHost?.enablePlugin(id: "com.example.plugin")
                }
            }
        }
    }
}
```

---

## Error Handling

### Common Scenarios

#### Plugin directory doesn't exist
```swift
// PluginHost gracefully handles missing directories
await pluginHost.loadInstalledPlugins()
// Result: returns empty array, prints error message
```

#### Invalid manifest.json
```swift
// Invalid JSON files are skipped
// Error logged to console
await pluginHost.loadInstalledPlugins()
// Result: continues with valid plugins
```

#### Enable non-existent plugin
```swift
await pluginHost.enablePlugin(id: "non.existent")
// Saves enablement state, but plugin not found
// No error, just logged
```

---

## Examples

### Basic Plugin Discovery

```swift
@MainActor
func discoverPlugins(tabManager: TabManager) async {
    guard let host = tabManager.pluginHost else { return }
    
    // Load installed plugins
    await host.loadInstalledPlugins()
    
    // Get plugin manager for current tab
    if let manager = host.getPluginManager(for: host.tabID) {
        let plugins = manager.getRegisteredPlugins()
        print("Found \(plugins.count) plugins:")
        for plugin in plugins {
            print("  - \(plugin.name)")
        }
    }
}
```

### Enable Multiple Plugins

```swift
@MainActor
func enableMultiplePlugins(tabManager: TabManager, ids: [String]) async {
    guard let host = tabManager.pluginHost else { return }
    
    for id in ids {
        await host.enablePlugin(id: id)
    }
}
```

### Check If Plugin Is Enabled

```swift
@MainActor
func isPluginEnabled(tabManager: TabManager, id: String) async -> Bool {
    guard let store = tabManager.pluginHost?.enablementStore else { return false }
    return await store.isEnabled(pluginID: id)
}
```

### Get All Enabled Plugins

```swift
@MainActor
func getEnabledPlugins(tabManager: TabManager) async -> [String] {
    guard let store = tabManager.pluginHost?.enablementStore else { return [] }
    return await store.getEnabledPlugins()
}
```

---

## Thread Safety Notes

All methods are `@MainActor` unless otherwise specified.

```swift
// ✅ Correct: Call on main thread
await pluginHost.loadInstalledPlugins()

// ✅ Correct: Inside Task with @MainActor
Task { @MainActor in
    await pluginHost.enablePlugin(id: "com.example.plugin")
}

// ✅ Correct: Actor isolation for enablement store
let enabled = await enablementStore.isEnabled(pluginID: "com.example.plugin")
```

---

## Future APIs (Planned)

```swift
// Monitor plugin lifecycle events
var onPluginLoaded: ((PluginManifest) -> Void)?
var onPluginUnloaded: ((String) -> Void)?

// Plugin communication
func sendMessageToPlugin(id: String, message: Any) async -> Any?

// Plugin discovery improvements
func searchPlugins(query: String) async -> [PluginManifest]
func checkForUpdates(pluginID: String) async -> UpdateInfo?
```
