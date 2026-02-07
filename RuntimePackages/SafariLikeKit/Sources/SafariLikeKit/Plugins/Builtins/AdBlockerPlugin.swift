import Foundation
import OSLog
import SafariLikeContracts

@MainActor
public final class AdBlockerPlugin: BrowserPlugin {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "webOS", category: "AdBlockerPlugin")

    public init() {}

    public let id: String = "com.safarilike.adblocker"
    public var kind: PluginKind { .policy }
    public let capabilities: Set<PluginCapability> = [.navigationIntercept]

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

    private var blockedCount: Int = 0
    private var allowedCount: Int = 0

    public func onLoad(context: any BrowserPluginContext) async throws {
        guard context.hasCapability(.navigationIntercept) else {
            throw PluginError.capabilityRequired(.navigationIntercept)
        }
        Self.logger.debug("AdBlockerPlugin loaded; domain rules: \(self.adDomains.count, privacy: .public)")
    }

    public func onUnload() async throws {
        Self.logger.debug("AdBlockerPlugin unloaded; blocked \(self.blockedCount, privacy: .public) allowed \(self.allowedCount, privacy: .public)")
    }

    public func shouldAllowNavigation(_ request: URLRequest) -> Bool {
        guard let urlString = request.url?.absoluteString else { return true }
        return shouldBlock(urlString) == false
    }

    public func interceptNavigation(_ request: NavigationRequest) -> InterceptionResponse {
        if shouldBlock(request.url) {
            blockedCount += 1
            Self.logger.debug("AdBlockerPlugin blocked \(request.url, privacy: .public)")
            return .block
        }
        allowedCount += 1
        return .allow
    }

    public func getStatistics() -> [String: Any] {
        let total = allowedCount + blockedCount
        return [
            "blocked": blockedCount,
            "allowed": allowedCount,
            "blockRate": total > 0 ? Double(blockedCount) / Double(total) : 0,
        ]
    }

    private func shouldBlock(_ url: String) -> Bool {
        let lowercaseURL = url.lowercased()
        for adDomain in adDomains {
            if lowercaseURL.contains(adDomain.lowercased()) {
                return true
            }
        }
        return false
    }
}
