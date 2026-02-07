import Foundation
import BrowserCore
import os
import SafariLikeContracts
/// Example Dark Mode Plugin - Demonstrates contentScripts capability
///
/// This sample stays within the Contracts boundary and does not directly
/// inject into WebKit; a host can use the returned CSS/script data.
@MainActor
public final class DarkModePlugin: BrowserPlugin {
    private static let logger = Logger(subsystem: "SafariLikeBuiltinPlugins", category: "DarkModePlugin")
    public init() {}
    public let id: String = "com.safarilike.darkmode"
    public let capabilities: Set<PluginCapability> = [.contentScripts, .navigationRead]
    private var isEnabled: Bool = true
    private(set) var didApplyForLastNavigation: Bool = false
    private let darkModeCSS = """
        @media (prefers-color-scheme: dark) {
            :root {
                color-scheme: dark;
            }
        }
        /* Force dark appearance on all pages when dark mode is on */
        html, body {
            background-color: #1e1e1e !important;
            color: #e0e0e0 !important;
        }
        a {
            color: #64b5f6 !important;
        }
        img {
            opacity: 0.85;
        }
        input, textarea, select {
            background-color: #2a2a2a !important;
            color: #e0e0e0 !important;
            border-color: #444 !important;
        }
        button {
            background-color: #444 !important;
            color: #e0e0e0 !important;
        }
    """
    public func onLoad(context: any BrowserPluginContext) async throws {
        guard context.hasCapability(.contentScripts) else {
            throw PluginError.capabilityRequired(.contentScripts)
        }
        let status = isEnabled ? "Enabled" : "Disabled"
        Self.logger.debug("DarkMode Plugin loaded; status: \(status, privacy: .public)")
    }
    public func onUnload() async throws {
        Self.logger.debug("DarkMode Plugin unloaded")
    }
    public func getDarkModeCSS() -> String {
        guard isEnabled else { return "" }
        return darkModeCSS
    }
    func shouldInjectOn(_ url: String) -> Bool {
        let blocklist = [
            "reddit.com",
            "github.com",
            "stackoverflow.com",
        ]
        let lowercaseURL = url.lowercased()
        return !blocklist.contains { lowercaseURL.contains($0) }
    }
    public func getDarkModeToInject(for url: String) -> String? {
        guard shouldInjectOn(url) else { return nil }
        guard isEnabled else { return nil }
        return getDarkModeCSS()
    }
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        let status = enabled ? "Enabled" : "Disabled"
        Self.logger.debug("DarkMode toggled: \(status, privacy: .public)")
    }
    public func isCurrentlyEnabled() -> Bool {
        isEnabled
    }
    public func navigationDidFinish(url: URL) throws {
        guard isEnabled else { return }
        didApplyForLastNavigation = true
        Self.logger.debug("DarkModePlugin navigationDidFinish for URL: \(url.absoluteString, privacy: .public)")
    }
}
