import Foundation
import os
import SafariLikeContracts
import SafariLikeCoreKit
/// Discovers and registers embedded (signed, bundled) dynamic plugins.
///
/// iOS constraints:
/// - No downloading/executing new code at runtime.
/// - Only load code that is shipped in the app bundle and code-signed.
///
/// This loader supports two packaging styles:
/// 1) Embedded frameworks in `Frameworks/` that declare `SafariLikePluginPrincipalClass` in Info.plist.
/// 2) Bundles in `PlugIns/` or `Plugins/` (resources) that declare the same key.
///
/// The principal class must be a Swift/ObjC class that conforms to `BrowserPlugin` and has a `public init()`.
@MainActor
enum DynamicPluginLoader {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "webOS", category: "SafariLikeKit.DynamicPluginLoader")
    private static let principalClassKey = "SafariLikePluginPrincipalClass"
    static func registerEmbeddedPlugins(allowedPluginIDs: Set<String>?) {
        let bundles = discoverCandidateBundles()
        guard bundles.isEmpty == false else { return }
        for bundle in bundles {
            guard let pluginType = resolvePluginType(from: bundle) else { continue }
            let pluginID = pluginType.init().id
            if let allowedPluginIDs, allowedPluginIDs.contains(pluginID) == false {
                logger.debug("Skipping embedded plugin (not allowlisted): \(pluginID, privacy: .public)")
                continue
            }
            CompileTimePluginRegistry.register(id: pluginID, factory: { pluginType.init() })
            logger.debug("Registered embedded plugin: \(pluginID, privacy: .public)")
        }
    }
    private static func discoverCandidateBundles() -> [Bundle] {
        var results: [Bundle] = []
        // 1) Embedded frameworks
        if let frameworksURL = Bundle.main.privateFrameworksURL {
            results.append(contentsOf: loadBundles(in: frameworksURL, matchingExtension: "framework"))
        }
        // 2) Built-in PlugIns directory
        if let pluginsURL = Bundle.main.builtInPlugInsURL {
            results.append(contentsOf: loadBundles(in: pluginsURL, matchingExtension: "bundle"))
            results.append(contentsOf: loadBundles(in: pluginsURL, matchingExtension: "framework"))
        }
        // 3) Resources/Plugins directory (resource plugins live here too)
        if let resourceURL = Bundle.main.resourceURL {
            let pluginsURL = resourceURL.appendingPathComponent("Plugins", isDirectory: true)
            results.append(contentsOf: loadBundles(in: pluginsURL, matchingExtension: "bundle"))
            results.append(contentsOf: loadBundles(in: pluginsURL, matchingExtension: "framework"))
        }
        // Keep deterministic order.
        return results.sorted { ($0.bundleURL.path) < ($1.bundleURL.path) }
    }
    private static func loadBundles(in directory: URL, matchingExtension ext: String) -> [Bundle] {
        let fm = FileManager.default
        guard (try? directory.checkResourceIsReachable()) == true else { return [] }
        guard let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }
        var bundles: [Bundle] = []
        for url in contents where url.pathExtension == ext {
            if let bundle = Bundle(url: url) {
                // Attempt to load; for frameworks this ensures the module is ready for NSClassFromString.
                _ = bundle.load()
                bundles.append(bundle)
            }
        }
        return bundles
    }
    private static func resolvePluginType(from bundle: Bundle) -> BrowserPlugin.Type? {
        // Prefer our explicit key; fall back to NSPrincipalClass.
        let className =
            (bundle.object(forInfoDictionaryKey: principalClassKey) as? String) ??
            (bundle.object(forInfoDictionaryKey: "NSPrincipalClass") as? String)
        guard let className, className.isEmpty == false else {
            return nil
        }
        guard let anyClass = NSClassFromString(className) else {
            logger.debug("Principal class not found: \(className, privacy: .public) in \(bundle.bundleURL.lastPathComponent, privacy: .public)")
            return nil
        }
        guard let pluginType = anyClass as? BrowserPlugin.Type else {
            logger.debug("Principal class does not conform to BrowserPlugin: \(className, privacy: .public)")
            return nil
        }
        return pluginType
    }
}
