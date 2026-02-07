import Foundation
import SafariLikeContracts
import SafariLikeCoreKit
/// Global registry for compile-time SafariLikeKit plugins.
///
/// This avoids any form of dynamic code loading at runtime.
/// Each plugin is compiled into the app and registered here using
/// its stable `id` as the lookup key.
///
/// Example:
/// ```swift
/// CompileTimePluginRegistry.register(
///     id: "com.example.adblocker",
///     factory: { AdBlockerPlugin() }
/// )
/// ```
@MainActor
public enum CompileTimePluginRegistry {
    public typealias PluginFactory = () -> BrowserPlugin
    /// Built-in plugin factories, keyed by plugin ID.
    ///
    /// Apps/frameworks should register plugins at startup by calling
    /// `CompileTimePluginRegistry.register(id:factory:)` (for example from
    /// `PluginBootstrap.registerBuiltInPlugins()`).
    private static var factories: [String: PluginFactory] = [:]
    /// Register or override a plugin factory for a given ID.
    public static func register(id: String, factory: @escaping PluginFactory) {
        factories[id] = factory
    }
    /// Look up a factory for the given plugin ID.
    public static func factory(for id: String) -> PluginFactory? {
        factories[id]
    }
    /// Resolve a concrete plugin instance for the given ID.
    ///
    /// This matches the simple API expected by the high-level
    /// plugin system: it constructs a fresh instance using the
    /// registered factory and returns it as `BrowserPlugin`
    /// if the type conforms to that protocol.
    public static func resolve(id: String) -> BrowserPlugin? {
        guard let factory = factories[id] else { return nil }
        return factory()
    }
    /// All known plugin IDs currently registered.
    public static func allKnownPluginIDs() -> [String] {
        Array(factories.keys)
    }
}
