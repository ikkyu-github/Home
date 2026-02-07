import Foundation
import OSLog
import SafariLikeCoreKit
/// Bootstraps built-in SafariLikeKit plugins into the global CompileTimePluginRegistry.
///
/// This should be called once during app startup (per process),
/// before any PluginHost attempts to resolve plugins by ID.
@MainActor
public enum PluginBootstrap {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "webOS",
        category: "SafariLikeKit.PluginBootstrap"
    )
    private static var didRegisterBuiltIns = false
    private static func allowedPluginIDsFromInfoPlist() -> Set<String>? {
        // Optional build-time allowlist. If missing, we allow all built-ins.
        // This allows Release builds to ship only explicitly enabled plugins.
        let key = "SafariLikeEnabledPluginIDs"
        if let ids = Bundle.main.object(forInfoDictionaryKey: key) as? [String] {
            return Set(ids)
        }
        if let csv = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            let parts = csv
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if parts.isEmpty { return nil }
            return Set(parts)
        }
        return nil
    }
    /// Register all built-in plugins with the global CompileTimePluginRegistry.
    ///
    /// - Note: This function is idempotent and safe to call multiple times,
    ///   but it will perform registration work only on the first call.
    public static func registerBuiltInPlugins() {
        guard !didRegisterBuiltIns else { return }
        didRegisterBuiltIns = true
        let allowlist = allowedPluginIDsFromInfoPlist()
        // Built-in plugins (compile-time)
        if allowlist?.contains("com.safarilike.adblocker") != false {
            CompileTimePluginRegistry.register(
                id: "com.safarilike.adblocker",
                factory: { AdBlockerPlugin() }
            )
        }
        if allowlist?.contains("com.safarilike.darkmode") != false {
            CompileTimePluginRegistry.register(
                id: "com.safarilike.darkmode",
                factory: { DarkModePlugin() }
            )
        }
        if allowlist?.contains("com.safarilike.analytics") != false {
            CompileTimePluginRegistry.register(
                id: "com.safarilike.analytics",
                factory: { AnalyticsPlugin() }
            )
        }
        // Dynamic plugins (embedded frameworks/bundles) may be registered here too.
        // If no embedded plugins exist, this is a no-op.
        DynamicPluginLoader.registerEmbeddedPlugins(allowedPluginIDs: allowlist)
        // Sanity check: ensure registry is not empty after bootstrap
        let allIDs = CompileTimePluginRegistry.allKnownPluginIDs()
        if allIDs.isEmpty {
            logger.warning("PluginBootstrap warning: no plugins registered in CompileTimePluginRegistry. Check bootstrap wiring.")
        }
    }
}
