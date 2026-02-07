import Foundation
import BrowserCore
import os
import SafariLikeContracts
/// Example AdBlocker Plugin - Demonstrates navigationIntercept capability
///
/// **What it does:**
/// - Blocks navigation to known ad domains
/// - Intercepts requests before page load
/// - Returns .block response to prevent loading
/// - Logs blocked domains
///
/// **Capabilities used:**
/// - `.navigationIntercept` - Can block/redirect navigation
@MainActor
public final class AdBlockerPlugin: BrowserPlugin {
    private static let logger = Logger(subsystem: "SafariLikeBuiltinPlugins", category: "AdBlockerPlugin")
    public init() {}
    /// Plugin identifier
    public let id: String = "com.safarilike.adblocker"
    public var kind: PluginKind { .policy }
    /// Declare what this plugin can do
    public let capabilities: Set<PluginCapability> = [.navigationIntercept]
    /// Common ad domain patterns to block
    private let adDomains = [
        "ads.google.com",
        "googleadservices.com",
        "doubleclick.net",
        "facebook.com/pixels",
        "youtube.com/api",
        "analytics.google.com",
        "segment.com",
        "amplitude.com",
        "mixpanel.com",
    ]
    /// Statistics tracking
    private var blockedCount: Int = 0
    private var allowedCount: Int = 0
    public func onLoad(context: any BrowserPluginContext) async throws {
        guard context.hasCapability(.navigationIntercept) else {
            throw PluginError.capabilityRequired(.navigationIntercept)
        }
        Self.logger.debug("AdBlocker Plugin loaded; will block \(self.adDomains.count, privacy: .public) ad domains")
    }
    public func onUnload() async throws {
        Self.logger.debug("AdBlocker Plugin unloaded; blocked \(self.blockedCount, privacy: .public) allowed \(self.allowedCount, privacy: .public)")
    }
    public func shouldAllowNavigation(_ request: URLRequest) -> Bool {
        guard let urlString = request.url?.absoluteString else { return true }
        return shouldBlock(urlString) == false
    }
    // MARK: - Ad blocking
    func shouldBlock(_ url: String) -> Bool {
        let lowercaseURL = url.lowercased()
        for adDomain in adDomains {
            if lowercaseURL.contains(adDomain.lowercased()) {
                return true
            }
        }
        return false
    }
    /// Intercept navigation request
    /// - Parameter request: Navigation request metadata
    /// - Returns: Interception response (.allow or .block)
    public func interceptNavigation(_ request: NavigationRequest) -> InterceptionResponse {
        if shouldBlock(request.url) {
            blockedCount += 1
            Self.logger.debug("AdBlocker blocked \(request.url, privacy: .public)")
            return .block
        }
        allowedCount += 1
        return .allow
    }
    public func getStatistics() -> [String: Any] {
        [
            "blocked": blockedCount,
            "allowed": allowedCount,
            "blockRate": allowedCount + blockedCount > 0 ? Double(blockedCount) / Double(allowedCount + blockedCount) : 0,
        ]
    }
}
