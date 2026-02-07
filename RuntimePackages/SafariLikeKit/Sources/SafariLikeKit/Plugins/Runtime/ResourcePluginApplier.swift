import Foundation
import WebKit
import CryptoKit
import SafariLikeCoreKit
import os
/// Applies resource plugins (content blockers, user scripts, and styles)
/// to a `WKWebViewConfiguration`.
@MainActor
final class ResourcePluginApplier {
    private static let logger = Logger(subsystem: "SafariLikeKit", category: "ResourcePluginApplier")
    private let ruleListStore: WKContentRuleListStore
    @MainActor
    init(ruleListStore: WKContentRuleListStore? = nil) {
        self.ruleListStore = ruleListStore ?? WKContentRuleListStore.default()
    }
    /// Apply enabled resource plugins to the given configuration.
    ///
    /// - Parameters:
    ///   - packages: Resolved resource plugin packages from `ResourcePluginLoader`.
    ///   - enabledPluginIDs: Set of plugin IDs that are currently enabled.
    ///   - configuration: WebKit configuration to mutate.
    func apply(
        packages: [ResourcePluginPackage],
        enabledPluginIDs: Set<String>,
        grantedPermissionsByPluginID: [String: Set<PluginPermission>],
        to configuration: WKWebViewConfiguration
    ) {
        let enabledPackages = packages.filter { enabledPluginIDs.contains($0.manifest.id) }
        guard !enabledPackages.isEmpty else { return }
        applyContentBlocking(
            from: enabledPackages,
            grantedPermissionsByPluginID: grantedPermissionsByPluginID,
            to: configuration
        )
        applyUserContent(
            from: enabledPackages,
            grantedPermissionsByPluginID: grantedPermissionsByPluginID,
            to: configuration
        )
    }
    // MARK: - Content Blocking
    private func applyContentBlocking(
        from packages: [ResourcePluginPackage],
        grantedPermissionsByPluginID: [String: Set<PluginPermission>],
        to configuration: WKWebViewConfiguration
    ) {
        let controller = configuration.userContentController
        for package in packages {
            guard package.manifest.requests(.contentBlocking) else { continue }
            let granted = grantedPermissionsByPluginID[package.manifest.id] ?? []
            guard granted.contains(.contentBlocking) else {
                Self.logger.debug("Denied content blocking for plugin \(package.manifest.id, privacy: .public): permission not granted")
                continue
            }
            for url in package.contentRuleListURLs {
                guard let json = try? String(contentsOf: url, encoding: .utf8) else { continue }
                let identifier = makeRuleListIdentifier(
                    pluginID: package.manifest.id,
                    version: package.manifest.version,
                    url: url,
                    contents: json
                )
                ruleListStore.lookUpContentRuleList(forIdentifier: identifier) { [weak ruleListStore] existing, _ in
                    if let existing = existing {
                        controller.add(existing)
                        return
                    }
                    ruleListStore?.compileContentRuleList(
                        forIdentifier: identifier,
                        encodedContentRuleList: json
                    ) { compiled, _ in
                        if let compiled = compiled {
                            controller.add(compiled)
                        }
                    }
                }
            }
        }
    }
    private func makeRuleListIdentifier(
        pluginID: String,
        version: String,
        url: URL,
        contents: String
    ) -> String {
        let data = Data((url.lastPathComponent + contents).utf8)
        let hash = SHA256.hash(data: data)
        let hashPrefix = hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16)
        return "plugin.\(pluginID).v\(version).\(hashPrefix)"
    }
    // MARK: - User Scripts & Styles
    private func applyUserContent(
        from packages: [ResourcePluginPackage],
        grantedPermissionsByPluginID: [String: Set<PluginPermission>],
        to configuration: WKWebViewConfiguration
    ) {
        let controller = configuration.userContentController
        for package in packages {
            guard package.manifest.requests(.contentScripts) else { continue }
            let granted = grantedPermissionsByPluginID[package.manifest.id] ?? []
            guard granted.contains(.contentScripts) else {
                Self.logger.debug("Denied content scripts for plugin \(package.manifest.id, privacy: .public): permission not granted")
                continue
            }
            // User scripts
            for resolved in package.userScripts {
                guard var source = try? String(contentsOf: resolved.url, encoding: .utf8) else { continue }
                // Wrap with host filter if allowedHosts is specified.
                if let hosts = resolved.definition.allowedHosts, !hosts.isEmpty,
                   let hostsData = try? JSONEncoder().encode(hosts),
                   let hostsJSON = String(data: hostsData, encoding: .utf8) {
                    source = """
                    (function() {
                      var allowedHosts = \(hostsJSON);
                      var host = window.location.host;
                      var ok = false;
                      for (var i = 0; i < allowedHosts.length; i++) {
                        var pattern = allowedHosts[i];
                        if (host === pattern || host.endsWith('.' + pattern)) {
                          ok = true;
                          break;
                        }
                      }
                      if (!ok) { return; }
                      (function() {
                    """ + source + """
                      })();
                    })();
                    """
                }
                let injectionTime: WKUserScriptInjectionTime
                switch resolved.definition.timing {
                case .atDocumentStart:
                    injectionTime = .atDocumentStart
                case .afterDocumentEnd:
                    injectionTime = .atDocumentEnd
                @unknown default:
                    injectionTime = .atDocumentEnd
                }
                let script = WKUserScript(
                    source: source,
                    injectionTime: injectionTime,
                    forMainFrameOnly: true
                )
                controller.addUserScript(script)
            }
            // Stylesheets are injected via JS wrapper that appends a <style> tag.
                        for resolved in package.styleSheets {
                                guard let css = try? String(contentsOf: resolved.url, encoding: .utf8) else { continue }
                                let escapedCSS = css
                                        .replacingOccurrences(of: "\\", with: "\\\\")
                                        .replacingOccurrences(of: "\"", with: "\\\"")
                                        .replacingOccurrences(of: "\n", with: "\\n")
                                var js = """
                                (function() {
                                    var style = document.createElement('style');
                                    style.type = 'text/css';
                                    style.innerHTML = "\(escapedCSS)";
                                    document.head.appendChild(style);
                                })();
                                """
                                if let hosts = resolved.definition.allowedHosts, !hosts.isEmpty,
                                     let hostsData = try? JSONEncoder().encode(hosts),
                                     let hostsJSON = String(data: hostsData, encoding: .utf8) {
                                        js = """
                                        (function() {
                                            var allowedHosts = \(hostsJSON);
                                            var host = window.location.host;
                                            var ok = false;
                                            for (var i = 0; i < allowedHosts.length; i++) {
                                                var pattern = allowedHosts[i];
                                                if (host === pattern || host.endsWith('.' + pattern)) {
                                                    ok = true;
                                                    break;
                                                }
                                            }
                                            if (!ok) { return; }
                                        """ + js + """
                                        })();
                                        """
                                }
                                let script = WKUserScript(
                                        source: js,
                                        injectionTime: .atDocumentEnd,
                                        forMainFrameOnly: true
                                )
                                controller.addUserScript(script)
            }
        }
    }
}
