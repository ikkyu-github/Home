# SafariLikeKit Plugin System

## Architecture

### PluginHost (@MainActor)
- Manages plugin lifecycle per window/scene
- Coordinates with PluginEnablementStore to track enabled/disabled plugins
- Creates and manages NextGenPluginManager instances per tab

**Location:** `SafariLikeKit/Plugins/Runtime/PluginHost.swift`

### PluginEnablementStore (Actor)
- Persists plugin enabled/disabled state to `Documents/enabled_plugins.json`
- Thread-safe access using Swift Actors
- Provides methods to enable/disable plugins

**Location:** `SafariLikeKit/Plugins/Runtime/PluginEnablementStore.swift`

### NextGenPluginManager (@MainActor)
- Per-tab plugin manager (one per tab in each window)
- Registers plugins and provides access to them
- Provides deterministic execution order + capability-based dispatch
- Enforces timeouts + best-effort cancellation + error isolation
- Records per-plugin metrics

**Location:** `SafariLikeKit/Plugins/Core/BrowserPluginManager.swift`

### Integration with NavigationService

NavigationService now accepts an optional `pluginHost` parameter:

```swift
init(tabManager: TabManager, pluginManager: NextGenPluginManager? = nil, pluginHost: PluginHost? = nil)
```

This allows plugins to:
1. Intercept navigation requests
2. Observe URL changes
3. Modify navigation behavior

## Plugin Types

### 1) Swift Plugins (compile-time)

Swift plugins are compiled into the app and registered via `CompileTimePluginRegistry`.
No dynamic Swift code loading is supported at runtime.

### 2) Resource Plugins (runtime resources)

Resource plugins are folders containing a `manifest.json` + content resources (JS/CSS/content-blocker rules).
These are applied by the runtime host to the WebKit configuration, without instantiating Swift types.

## Resource Plugin Installation

Plugins are installed to `~/Documents/Plugins/` directory.

Each plugin must have:

```
~/Documents/Plugins/my-plugin/
├── manifest.json
├── plugin.js (or swift if native)
└── resources/
```

### manifest.json Format

```json
{
  "id": "com.example.plugin",
  "name": "Example Plugin",
  "version": "1.0.0",
    "permissions": ["navigationRead", "contentScripts"],
    "contentRuleLists": ["rules.json"],
    "userScripts": [{"id":"inject","path":"inject.js","timing":"afterDocumentEnd"}],
    "styleSheets": [{"id":"dark","path":"dark.css"}]
}
```

## Lifecycle

1. **Initialization:** TabManager creates PluginHost on init
2. **Enablement:** PluginEnablementStore persists enabled IDs
3. **Load (Swift plugins):** PluginHost installs/enables compile-time plugins via RuntimePluginRegistry
4. **Load (resource plugins):** ResourcePluginLoader discovers manifests and applies WebKit resources
5. **Shutdown:** PluginHost.shutdown() called when scene/window closes

## Threading Rules (Contract)

### What runs on MainActor
- Swift plugin lifecycle (`onLoad`, `onEnable`, `onDisable`, `onUnload`) and context APIs in `PluginContext`.
- Hook handlers registered through `PluginContext` are currently treated as MainActor callbacks.

### What may run in background
- Plugins may spawn background work using `Task.detached` (or their own actors) for CPU/network work.
- Any expensive work MUST be offloaded; hooks should return quickly and avoid blocking MainActor.

### Cancellation
- Hook wrappers respect Task cancellation and attempt best-effort cancellation.
- Plugin code must periodically `await` (or check cancellation) to be cancellable.

### Crash isolation
- The system catches thrown errors and timeouts and can auto-disable misbehaving plugins.
- Swift fatal errors / process crashes cannot be reliably isolated in-process; plugins must avoid `fatalError`, infinite loops, and blocking MainActor.

## Deterministic Ordering

- Compile-time plugin IDs are enumerated deterministically.
- Dispatch order is deterministic by default and supports an optional priority hint:
    - Adopt `PluginOrdering` and return higher `pluginPriority` to run earlier.

## Metrics

Per plugin:
- Total hook time (accumulated)
- Per-hook call counts + last duration
- Intercept count (non-allow interception)
- Error count + failure count

## Checklist (Plugin System Standards)

- [ ] Every plugin hook is invoked via a wrapper that enforces timeout.
- [ ] Cancellation is respected; wrapper short-circuits when cancelled.
- [ ] Errors are caught per plugin; one plugin cannot break the chain.
- [ ] Ordering is deterministic (priority then id).
- [ ] Capability-based filtering is applied before dispatch.
- [ ] Metrics are recorded per plugin for time, counts, intercepts, errors.

## API Contract for Plugin Writers

Choose one:
- Simple API: conform to `BrowserPlugin` (navigation notifications + optional policy via `PolicyPlugin`).
- Advanced API: conform to `BrowserPluginContract` and declare `capabilities`, then use `PluginContext` APIs.

Rules:
- Keep hooks fast; do not block MainActor.
- Declare only needed capabilities.
- Handle cancellation in async work.
- Avoid crashes (`fatalError`) and avoid unbounded loops.

## Usage in TabManager

```swift
init(...) {
    // ...
    self.pluginHost = PluginHost(
        windowID: UUID(),
        tabID: initialActiveTabID,
        enablementStore: enablementStore
    )
    
    // Load installed plugins after session init
    Task { @MainActor [weak self] in
        await self?.pluginHost?.loadInstalledPlugins()
    }
}
```

## Storage

### Enablement State
File: `~/Documents/enabled_plugins.json`

```json
["com.example.plugin1", "com.example.plugin2"]
```

Updated whenever plugins are enabled/disabled.

### Plugin Files
Directory: `~/Documents/Plugins/`

- Each subdirectory is a plugin
- Must contain manifest.json
- Can contain any additional files needed by the plugin

## Future Enhancements

1. **Plugin Sandboxing:** Use WKWebViewConfiguration + messageHandlers
2. **Plugin Communication:** MessagePort between plugins
3. **Plugin Auto-Update:** Check for updates on launch
4. **Plugin Permissions UI:** Request user consent for sensitive permissions
5. **Plugin Crash Recovery:** Isolate plugin crashes from main app
