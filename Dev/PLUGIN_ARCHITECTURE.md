# Plugin System Architecture Diagram

## Component Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                       TabManager                            │
│  @MainActor final class                                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  PluginHost                                         │   │
│  │  @MainActor final class                            │   │
│  │  windowID: UUID                                     │   │
│  │  tabID: UUID                                        │   │
│  ├────────────────────────────────────────────────────┤   │
│  │                                                      │   │
│  │  ┌──────────────────────────────────────────────┐  │   │
│  │  │ PluginEnablementStore                        │  │   │
│  │  │ actor                                         │  │   │
│  │  │ - enabled_plugins.json (Documents/)         │  │   │
│  │  │ - isEnabled(pluginID)                        │  │   │
│  │  │ - enable/disable(pluginID)                   │  │   │
│  │  └──────────────────────────────────────────────┘  │   │
│  │                                                      │   │
│  │  ┌──────────────────────────────────────────────┐  │   │
│  │  │ NextGenPluginManager (per-tab)               │  │   │
│  │  │ @MainActor class                             │  │   │
│  │  │ - windowID, tabID                            │  │   │
│  │  │ - registerPlugin(manifest)                   │  │   │
│  │  └──────────────────────────────────────────────┘  │   │
│  │                                                      │   │
│  │  Methods:                                            │   │
│  │  - loadInstalledPlugins() async                     │   │
│  │  - registerEnabledPlugins() async                   │   │
│  │  - enablePlugin(id) async                           │   │
│  │  - disablePlugin(id) async                          │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  NavigationService                                 │   │
│  │  final class                                        │   │
│  │  - weak pluginHost: PluginHost?                     │   │
│  │  - Consults pluginHost during navigation            │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

### Initialization (on app launch)

```
App Launch
  │
  ├─→ Create TabManager
  │   │
  │   ├─→ Create PluginEnablementStore
  │   │   └─→ Load ~/Documents/enabled_plugins.json
  │   │
  │   ├─→ Create PluginHost
  │   │   └─→ windowID, tabID, enablementStore
  │   │
  │   ├─→ Create NavigationService (lazy)
  │   │   └─→ Pass pluginHost reference
  │   │
  │   └─→ Task: loadInstalledPlugins() async
  │       │
  │       ├─→ Scan ~/Documents/Plugins/
  │       ├─→ Load manifest.json for each
  │       ├─→ Filter by enabled plugins only
  │       └─→ Call NextGenPluginManager.registerPlugin()
  │
  └─→ Ready for navigation
```

### Plugin Enable/Disable

```
User Action (Settings UI or code)
  │
  ├─→ await tabManager.pluginHost?.enablePlugin(id)
  │   │
  │   ├─→ PluginEnablementStore.enable(pluginID)
  │   │   └─→ Save to ~/Documents/enabled_plugins.json
  │   │
  │   └─→ Discover and register plugin
  │       └─→ Call NextGenPluginManager.registerPlugin()
  │
  └─→ Plugin active immediately
```

### Navigation Request

```
User navigates (URL bar, link, redirect)
  │
  ├─→ NavigationService.loadURLString()
  │   │
  │   ├─→ Check pluginHost for plugins
  │   │   └─→ Plugins can intercept/monitor
  │   │
  │   └─→ Execute navigation
  │
  └─→ Continue normal navigation flow
```

## File Structure

```
~/Documents/
├── enabled_plugins.json          ← Persistent enablement state
│   [
│     "com.example.plugin1",
│     "com.example.plugin2"
│   ]
│
└── Plugins/                       ← Plugin installation directory
    ├── plugin-1/
    │   ├── manifest.json          ← Plugin metadata
    │   ├── plugin.js              ← Main plugin code
    │   └── resources/
    │       └── ...
    │
    └── plugin-2/
        ├── manifest.json
        ├── plugin.swift           ← or native code
        └── ...
```

## Storage Schema

### enabled_plugins.json

```json
[
  "com.example.dark-mode",
  "com.example.ad-blocker",
  "com.example.custom-fonts"
]
```

### Plugin Manifest (manifest.json)

```json
{
  "id": "com.example.plugin-id",
  "name": "Plugin Display Name",
  "version": "1.0.0",
  "entryPoint": "plugin.js",
  "permissions": [
    "navigation",
    "webview",
    "storage",
    "downloads"
  ]
}
```

## Thread Safety Model

```
┌──────────────────────────────────────────┐
│ MainActor                                │
├──────────────────────────────────────────┤
│ - TabManager                             │
│ - PluginHost                             │
│ - NavigationService                      │
│ - NextGenPluginManager                   │
│                                          │
│ All UI updates and lifecycle happens    │
│ on the main thread                      │
└──────────────────────────────────────────┘
         ↓ (async/await bridge)
┌──────────────────────────────────────────┐
│ Actor                                    │
├──────────────────────────────────────────┤
│ - PluginEnablementStore                  │
│                                          │
│ Thread-safe persistent state access     │
│ (file I/O, JSON parsing)                │
└──────────────────────────────────────────┘
```

## Integration with NavigationService

```
NavigationService
  │
  ├─→ weak reference to PluginHost
  │   └─→ Can query active plugins
  │       └─→ Get plugin manager
  │           └─→ Query registered plugins
  │
  └─→ Before/during/after navigation:
      ├─→ Notify plugins of navigation intent
      ├─→ Allow plugins to intercept (future)
      └─→ Report navigation outcome
```

## Lifecycle Events

```
1. App Launch
   └─→ TabManager creates PluginHost
   └─→ PluginHost discovers plugins
   └─→ Enabled plugins registered

2. Plugin Installation
   └─→ User/installer creates ~/Documents/Plugins/{id}/
   └─→ Next app session discovers new plugin
   └─→ Plugin appears in settings (not enabled by default)

3. Plugin Enable
   └─→ User enables in settings
   └─→ Saved to enabled_plugins.json
   └─→ Plugin manager registers plugin

4. Plugin Usage
   └─→ Plugin receives navigation events
   └─→ Plugin can modify behavior
   └─→ Navigation continues normally

5. Plugin Disable
   └─→ User disables in settings
   └─→ Removed from enabled_plugins.json
   └─→ Plugin manager unloads plugin

6. App Termination
   └─→ PluginHost.shutdown() called
   └─→ Plugin managers cleaned up
```
