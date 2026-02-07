import Foundation
import Combine
import SafariLikeCoreKit
/// ViewModel for managing compile-time plugins (per window).
///
/// - Source of truth for available plugin IDs: `CompileTimePluginRegistry.allKnownPluginIDs()`.
/// - Source of truth for enabled state: `PluginEnablementStore(windowID:)` (UserDefaults-backed).
/// - Side effects: forwarded to the runtime via `BrowserRuntimeIntentDispatching`.
@MainActor
public final class PluginManagerViewModel: ObservableObject {
    @Published public private(set) var pluginIDs: [String] = []
    @Published public private(set) var enabledPluginIDs: Set<String> = []
    @Published public private(set) var grantedPermissionsByPluginID: [String: Set<PluginPermission>] = [:]
    @Published public private(set) var isUIEnabled: Bool = false
    @Published public private(set) var statusMessage: String? = nil
    private weak var runtime: (any BrowserRuntimeIntentDispatching)?
    private var enablementStore: PluginEnablementStore?
    public init() {}
    public func configure(windowID: BrowserWindowID?, runtime: (any BrowserRuntimeIntentDispatching)?) {
        self.runtime = runtime
        guard let windowID else {
            enablementStore = nil
            pluginIDs = []
            enabledPluginIDs = []
            isUIEnabled = false
            statusMessage = "No window context"
            return
        }
        enablementStore = PluginEnablementStore(windowID: windowID.value.uuidString)
        isUIEnabled = (runtime != nil)
        statusMessage = (runtime == nil) ? "No runtime" : nil
        Task { @MainActor in
            await refresh()
        }
    }
    public func refresh() async {
        pluginIDs = CompileTimePluginRegistry.allKnownPluginIDs().sorted()
        guard let enablementStore else {
            enabledPluginIDs = []
            return
        }
        await enablementStore.loadEnablementState()
        let enabled = await enablementStore.getEnabledPlugins()
        enabledPluginIDs = Set(enabled)
        grantedPermissionsByPluginID = await enablementStore.getGrantedPermissionsByPluginID()
    }
    public func isEnabled(_ pluginID: String) -> Bool {
        enabledPluginIDs.contains(pluginID)
    }
    public func isPermissionGranted(_ permission: PluginPermission, pluginID: String) -> Bool {
        (grantedPermissionsByPluginID[pluginID] ?? []).contains(permission)
    }
    public func setPermission(
        _ granted: Bool,
        permission: PluginPermission,
        pluginID: String
    ) async {
        guard isUIEnabled else { return }
        guard let enablementStore else { return }
        await enablementStore.setPermission(permission, granted: granted, for: pluginID)
        await refresh()
    }
    public func setEnabled(_ enabled: Bool, pluginID: String) async {
        guard let runtime else { return }
        guard isUIEnabled else { return }
        if enabled {
            runtime.send(intent: .enablePlugin(id: pluginID))
        } else {
            runtime.send(intent: .disablePlugin(id: pluginID))
        }
        await refresh()
    }
}
