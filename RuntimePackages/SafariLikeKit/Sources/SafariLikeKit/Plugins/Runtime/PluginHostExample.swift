#if DEBUG

import Foundation
import os
import SafariLikeCoreKit

/// Demo-only pseudo-code. See also: `Docs/Plugins/PLUGIN_HOST_EXAMPLES.md`.
nonisolated func examplePluginHostUsage() {
    // This is pseudo-code showing how PluginHost is integrated
    /*
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
    */
}

/// Example Plugin Installation Instructions
let EXAMPLE_PLUGIN_STRUCTURE = """
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
"""

/// Example: Access PluginManager from NavigationService
let EXAMPLE_PLUGIN_NAVIGATION = """
// In NavigationService, you can now access pluginHost:
func loadURLString(_ urlString: String, force: Bool = false) {
    // Notify plugins about navigation
    if let pluginHost = pluginHost {
        // Plugins can intercept or monitor navigation
        let logger = Logger(subsystem: "SafariLikeKit", category: "PluginHostExample")
        logger.debug("Navigating to: \\(urlString, privacy: .public)")
    }
    // Continue with normal navigation...
}
"""

#endif
