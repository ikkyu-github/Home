import Foundation
import os
import SafariLikeCoreKit
import SafariLikeContracts
import WebKit
import ObjectiveC

extension PluginHost {
    // MARK: - Host lifecycle

    func shutdown() async {
        if let observer = enablementObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        enablementObserver = nil

        let ids = Array(pluginRegistry.installedPlugins.keys)
        for pluginID in ids {
            await pluginRegistry.uninstall(pluginID: pluginID)
        }

        pluginManagers.removeAll(keepingCapacity: false)
        cachedResourcePackages.removeAll(keepingCapacity: false)
        cachedEnabledPluginIDs.removeAll(keepingCapacity: false)
        cachedGrantedPermissionsByPluginID.removeAll(keepingCapacity: false)
        errorCounts.removeAll(keepingCapacity: false)
    }

    // MARK: - Simple plugin hooks (BrowserPlugin)

    func navigationWillStart(url: URL) async {
        for (id, plugin) in pluginRegistry.enabledPluginsInOrder() {
            do {
                try plugin.navigationWillStart(url: url)
            } catch {
                errorCounts[id, default: 0] += 1
                Self.logger.error("Plugin navigationWillStart failed: \(id, privacy: .public) \(String(describing: error), privacy: .public)")
            }
        }
    }

    func navigationDidFinish(url: URL) async {
        for (id, plugin) in pluginRegistry.enabledPluginsInOrder() {
            do {
                try plugin.navigationDidFinish(url: url)
            } catch {
                errorCounts[id, default: 0] += 1
                Self.logger.error("Plugin navigationDidFinish failed: \(id, privacy: .public) \(String(describing: error), privacy: .public)")
            }
        }
    }

    func navigationDidFail(url: URL, error: Error) async {
        for (id, plugin) in pluginRegistry.enabledPluginsInOrder() {
            do {
                try plugin.navigationDidFail(url: url, error: error)
            } catch {
                errorCounts[id, default: 0] += 1
                Self.logger.error("Plugin navigationDidFail failed: \(id, privacy: .public) \(String(describing: error), privacy: .public)")
            }
        }
    }

    func tabWillFreeze(tabID: UUID) async {
        let id = tabID.uuidString
        for (pluginID, plugin) in pluginRegistry.enabledPluginsInOrder() {
            do {
                try await plugin.webViewWillDetach(tabID: id)
            } catch {
                Self.logger.error("Plugin webViewWillDetach failed: \(pluginID, privacy: .public) \(String(describing: error), privacy: .public)")
            }
        }
    }

    func tabWillEvict(tabID: UUID) async {
        let id = tabID.uuidString
        for (pluginID, plugin) in pluginRegistry.enabledPluginsInOrder() {
            do {
                try await plugin.tabWillEvict(tabID: id)
            } catch {
                Self.logger.error("Plugin tabWillEvict failed: \(pluginID, privacy: .public) \(String(describing: error), privacy: .public)")
            }
        }
    }

    // MARK: - Resource plugin application

    func refreshResourcePluginCache() async {
        cachedEnabledPluginIDs = Set(await enablementStore.getEnabledPlugins())
        cachedGrantedPermissionsByPluginID = await enablementStore.getGrantedPermissionsByPluginID()
        cachedResourcePackages = await resourceLoader.loadAllPlugins()
    }

    func applyResourcePluginsIfNeeded(to configuration: WKWebViewConfiguration) {
        if objc_getAssociatedObject(configuration, &Self.resourceAppliedAssociationKey) != nil {
            return
        }
        objc_setAssociatedObject(configuration, &Self.resourceAppliedAssociationKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // Resource plugins mutate configuration only (no WKWebView exposure).
        resourceApplier.apply(
            packages: cachedResourcePackages,
            enabledPluginIDs: cachedEnabledPluginIDs,
            grantedPermissionsByPluginID: cachedGrantedPermissionsByPluginID,
            to: configuration
        )
    }
}
