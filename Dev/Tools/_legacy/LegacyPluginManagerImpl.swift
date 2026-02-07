import Foundation

/// Default implementation of BrowserPluginManager.
@MainActor
public final class PluginManagerImpl: BrowserPluginManager {
    
    private var plugins: [String: BrowserPlugin] = [:]
    
    public init() {}
    
    public func register(_ plugin: BrowserPlugin) {
        plugins[plugin.pluginID] = plugin
        plugin.onRegister(coordinator: self)
    }
    
    public func unregister(_ pluginID: String) {
        if let plugin = plugins.removeValue(forKey: pluginID) {
            plugin.onUnregister()
        }
    }
    
    public func plugin(by id: String) -> BrowserPlugin? {
        plugins[id]
    }
    
    public func allPlugins() -> [BrowserPlugin] {
        Array(plugins.values)
    }
    
    /// Try custom URL handling via plugins
    func handleCustomURL(_ url: URL) -> Bool {
        for plugin in allPlugins() {
            if plugin.canHandle(url: url) {
                return plugin.handle(url: url)
            }
        }
        return false
    }
}
