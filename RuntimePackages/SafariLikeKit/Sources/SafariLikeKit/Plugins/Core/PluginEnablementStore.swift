import Foundation
import SafariLikeCoreKit
/// Stores enabled/disabled state for plugins on a per-window basis.
///
/// Persistence is backed by `UserDefaults` as a minimal, iOS-safe
/// implementation. Each `windowID` gets its own key-space so that
/// multiple windows/scenes do not share plugin enablement implicitly.
actor PluginEnablementStore {
    private let windowID: String
    private let userDefaults: UserDefaults
    /// In-memory cache of enabled plugin IDs for this window.
    private var enabledPlugins: Set<String> = []
    /// In-memory cache of granted permissions per plugin ID.
    ///
    /// Default is empty (deny-all) unless the user explicitly grants.
    private var grantedPermissionsByPluginID: [String: Set<PluginPermission>] = [:]
    /// Base key prefix for values stored in UserDefaults.
    private static let storagePrefix = "SafariLikeKit.PluginEnablement."
    /// Notification posted whenever enablement or granted permissions change.
    static let didChangeNotification = Notification.Name("SafariLikeKit.PluginEnablementStore.didChange")
    /// Designated initializer scoped to a specific window.
    init(windowID: String) {
        self.windowID = windowID
        self.userDefaults = .standard
    }
    /// Convenience initializer used by tests/demo code where a
    /// globally scoped enablement store is sufficient.
    init() {
        self.windowID = "global"
        self.userDefaults = .standard
    }
    // MARK: - Persistence Helpers
    private var legacyEnabledStorageKey: String {
        Self.storagePrefix + windowID
    }
    private var enabledStorageKey: String {
        Self.storagePrefix + windowID + ".enabled"
    }
    private var permissionsStorageKey: String {
        Self.storagePrefix + windowID + ".permissions"
    }
    /// Load enablement state from UserDefaults.
    func loadEnablementState() async {
        if let array = userDefaults.array(forKey: enabledStorageKey) as? [String] {
            enabledPlugins = Set(array)
        } else if let array = userDefaults.array(forKey: legacyEnabledStorageKey) as? [String] {
            // Backward compatibility: older versions stored enabled IDs directly at the legacy key.
            enabledPlugins = Set(array)
        } else {
            enabledPlugins = []
        }
        if let raw = userDefaults.dictionary(forKey: permissionsStorageKey) as? [String: [String]] {
            var parsed: [String: Set<PluginPermission>] = [:]
            parsed.reserveCapacity(raw.count)
            for (pluginID, list) in raw {
                let perms = Set(list.compactMap { PluginPermission(permissionString: $0) })
                if perms.isEmpty {
                    parsed[pluginID] = []
                } else {
                    parsed[pluginID] = perms
                }
            }
            grantedPermissionsByPluginID = parsed
        } else {
            grantedPermissionsByPluginID = [:]
        }
    }
    private func persistEnabled() {
        let array = Array(enabledPlugins)
        userDefaults.set(array, forKey: enabledStorageKey)
        // Also write legacy key so users don't lose state during upgrades/downgrades.
        userDefaults.set(array, forKey: legacyEnabledStorageKey)
    }
    private func persistPermissions() {
        let raw: [String: [String]] = grantedPermissionsByPluginID.mapValues { perms in
            perms.map { $0.rawValue }.sorted()
        }
        userDefaults.set(raw, forKey: permissionsStorageKey)
    }
    private func notifyChanged() {
        NotificationCenter.default.post(
            name: Self.didChangeNotification,
            object: nil,
            userInfo: ["windowID": windowID]
        )
    }
    // MARK: - High-level API (spec)
    /// Returns whether the given plugin ID is enabled for this window.
    func isEnabled(pluginID: String) -> Bool {
        enabledPlugins.contains(pluginID)
    }
    /// Enable or disable a plugin and persist the change.
    func setEnabled(_ enabled: Bool, for pluginID: String) async {
        if enabled {
            enabledPlugins.insert(pluginID)
        } else {
            enabledPlugins.remove(pluginID)
        }
        persistEnabled()
        notifyChanged()
    }
    // MARK: - Permissions
    func grantedPermissions(pluginID: String) -> Set<PluginPermission> {
        grantedPermissionsByPluginID[pluginID] ?? []
    }
    func isGranted(_ permission: PluginPermission, for pluginID: String) -> Bool {
        (grantedPermissionsByPluginID[pluginID] ?? []).contains(permission)
    }
    func setPermission(_ permission: PluginPermission, granted: Bool, for pluginID: String) async {
        var set = grantedPermissionsByPluginID[pluginID] ?? []
        if granted {
            set.insert(permission)
        } else {
            set.remove(permission)
        }
        grantedPermissionsByPluginID[pluginID] = set
        persistPermissions()
        notifyChanged()
    }
    func setGrantedPermissions(_ permissions: Set<PluginPermission>, for pluginID: String) async {
        grantedPermissionsByPluginID[pluginID] = permissions
        persistPermissions()
        notifyChanged()
    }
    func getGrantedPermissionsByPluginID() -> [String: Set<PluginPermission>] {
        grantedPermissionsByPluginID
    }
    // MARK: - Compatibility Helpers
    /// Returns all enabled plugin IDs for this window.
    func getEnabledPlugins() -> [String] {
        Array(enabledPlugins)
    }
    /// Enable a plugin (legacy convenience).
    func enable(pluginID: String) {
        enabledPlugins.insert(pluginID)
        persistEnabled()
        notifyChanged()
    }
    /// Disable a plugin (legacy convenience).
    func disable(pluginID: String) {
        enabledPlugins.remove(pluginID)
        persistEnabled()
        notifyChanged()
    }
    /// Reset all enablement state for this window.
    func reset() {
        enabledPlugins.removeAll()
        grantedPermissionsByPluginID.removeAll()
        persistEnabled()
        persistPermissions()
        notifyChanged()
    }
}
