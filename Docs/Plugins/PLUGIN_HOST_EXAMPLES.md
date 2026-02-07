# PluginHost example and test snippets

This document contains the former in-repo example/demo code that previously lived under SafariLikeKit production sources.

Rationale:
- Keep production `Sources/` free of pseudo-code and demo-only APIs.
- Avoid accidental shipping of example logging and filesystem paths.

## Example: PluginHost usage with TabManager

The following is pseudo-code showing how PluginHost is integrated.

```swift
@MainActor
class ExampleViewController {
    func initializeTabManager() {
        let tabManager = TabManager(
            normalSessionStore: store,
            privateSessionStore: privateStore,
            normalTabRegistry: normalRegistry,
            privateTabRegistry: privateRegistry,
            defaultHomeURLString: "https://example.com",
            historyStore: historyStore,
            downloadStore: downloadStore,
            initialActiveTabID: UUID()
        )

        // PluginHost is automatically created inside TabManager.init
        // Plugins are loaded asynchronously

        // Later: enable/disable plugins
        Task { @MainActor in
            await tabManager.pluginHost?.enablePlugin(id: "com.example.plugin")
            // or
            await tabManager.pluginHost?.disablePlugin(id: "com.example.plugin")
        }
    }
}
```

## Example: plugin installation structure

```text
To install a plugin:
1. Create directory in ~/Documents/Plugins/
   $ mkdir -p ~/Documents/Plugins/my-plugin
2. Create manifest.json:
   $ cat > ~/Documents/Plugins/my-plugin/manifest.json << 'EOF'
   {
     "id": "com.example.my-plugin",
     "name": "My Plugin",
     "version": "1.0.0",
     "entryPoint": "plugin.js",
     "permissions": ["navigation", "webview"]
   }
   EOF
3. Add plugin code (plugin.js or Swift code):
   $ cat > ~/Documents/Plugins/my-plugin/plugin.js << 'EOF'
   // Your plugin code here
   console.log("Plugin loaded!");
   EOF
4. Plugin will be discovered automatically on next app launch
   or when you call: await pluginHost?.loadInstalledPlugins()
5. Enable the plugin via UI or code:
   await tabManager.pluginHost?.enablePlugin(id: "com.example.my-plugin")
```

## Example: navigation hook logging (pseudo-code)

```swift
func loadURLString(_ urlString: String, force: Bool = false) {
    // Notify plugins about navigation
    if let pluginHost = pluginHost {
        let logger = Logger(subsystem: "SafariLikeKit", category: "PluginHostExample")
        logger.debug("Navigating to: \\\(urlString)")
    }

    // Continue with normal navigation...
}
```

## Demo: plugin discovery / enablement (pseudo-code)

```swift
@MainActor
func testPluginDiscovery() async {
    let store = PluginEnablementStore()
    await store.loadEnablementState()

    let (repo, _) = LibraryStoreFactory.sharedRepository()
    let host = PluginHost(
        windowID: UUID().uuidString,
        tabID: UUID().uuidString,
        webContextManager: WebContextManager(),
        enablementStore: store,
        normalSessionStore: BrowserSessionStore(persistence: .memory),
        privateSessionStore: BrowserSessionStore(persistence: .memory),
        libraryRepository: repo
    )

    await host.loadInstalledPlugins()

    if let manager = host.getPluginManager(for: host.tabID) {
        let allPlugins = manager.allPlugins()
        let enabledPlugins = manager.enabledPlugins()
        print("Discovered \\\(allPlugins.count) plugins")
        print("Enabled \\\(enabledPlugins.count) plugins")
    }
}

@MainActor
func testPluginEnablement() async {
    let store = PluginEnablementStore()
    await store.loadEnablementState()

    let (repo, _) = LibraryStoreFactory.sharedRepository()
    let host = PluginHost(
        windowID: UUID().uuidString,
        tabID: UUID().uuidString,
        webContextManager: WebContextManager(),
        enablementStore: store,
        normalSessionStore: BrowserSessionStore(persistence: .memory),
        privateSessionStore: BrowserSessionStore(persistence: .memory),
        libraryRepository: repo
    )

    await host.enablePlugin(id: "com.example.test-plugin")
    await host.disablePlugin(id: "com.example.test-plugin")
}
```

## Demo: create an example plugin folder (pseudo-code)

```swift
func createExamplePluginStructure() {
    let fileManager = FileManager.default
    let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let pluginsDir = documents.appendingPathComponent("Plugins")
    let examplePluginDir = pluginsDir.appendingPathComponent("example-plugin")

    try? fileManager.createDirectory(at: examplePluginDir, withIntermediateDirectories: true)

    let manifestURL = examplePluginDir.appendingPathComponent("manifest.json")
    let manifest = """
    {
      "id": "com.example.plugin",
      "name": "Example Plugin",
      "version": "1.0.0",
      "entryPoint": "plugin.js",
      "permissions": ["navigation", "webview"]
    }
    """

    try? manifest.write(to: manifestURL, atomically: true, encoding: .utf8)
}
```
