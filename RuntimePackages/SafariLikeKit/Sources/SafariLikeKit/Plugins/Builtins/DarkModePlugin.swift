import Foundation
import OSLog
import SafariLikeContracts

@MainActor
public final class DarkModePlugin: BrowserPlugin {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "webOS", category: "DarkModePlugin")

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
        Self.logger.debug("DarkModePlugin loaded; enabled: \(self.isEnabled, privacy: .public)")
    }

    public func onUnload() async throws {
        Self.logger.debug("DarkModePlugin unloaded")
    }

    public func getDarkModeToInject(for url: String) -> String? {
        guard isEnabled else { return nil }
        guard shouldInjectOn(url) else { return nil }
        return darkModeCSS
    }

    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Self.logger.debug("DarkModePlugin toggled; enabled: \(enabled, privacy: .public)")
    }

    public func isCurrentlyEnabled() -> Bool {
        isEnabled
    }

    public func navigationDidFinish(url: URL) throws {
        guard isEnabled else { return }
        didApplyForLastNavigation = true
        Self.logger.debug("DarkModePlugin navigationDidFinish \(url.absoluteString, privacy: .public)")
    }

    private func shouldInjectOn(_ url: String) -> Bool {
        let blocklist = [
            "reddit.com",
            "github.com",
            "stackoverflow.com",
        ]
        let lowercaseURL = url.lowercased()
        return !blocklist.contains { lowercaseURL.contains($0) }
    }
}
