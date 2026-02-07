import Foundation
import SafariLikeCoreKit
public struct NavigationPolicy: PolicyProviding {
    public let id: String = "core.navigation"
    public let kind: PolicyProviderKind = .core
    public let priority: Int = 100
    public var allowFileURLs: Bool = false
    public var allowDataURLMainFrame: Bool = false
    public var allowJavaScriptURLMainFrame: Bool = false
    public var upgradeToHTTPS: Bool = false
    private let externalSchemes: Set<String> = ["tel", "mailto", "itms-apps"]
    public init() {}
    public func decideNavigation(_ ctx: NavigationContext) async -> PolicyDecision? {
        let scheme = ctx.url.scheme?.lowercased() ?? ""
        if scheme == "about", ctx.url.absoluteString == "about:blank" {
            return .allow
        }
        if scheme == "file" {
            return allowFileURLs ? .allow : .cancel(reason: "file_scheme")
        }
        if scheme == "data" {
            if ctx.isMainFrame {
                return allowDataURLMainFrame ? .allow : .cancel(reason: "data_mainframe")
            }
            return .allow
        }
        if scheme == "javascript" {
            return allowJavaScriptURLMainFrame ? .allow : .cancel(reason: "javascript_url")
        }
        if externalSchemes.contains(scheme) {
            return .cancel(reason: "external_scheme")
        }
        if upgradeToHTTPS, scheme == "http", ctx.isMainFrame {
            if var comps = URLComponents(url: ctx.url, resolvingAgainstBaseURL: false) {
                comps.scheme = "https"
                if let upgraded = comps.url {
                    return .cancel(reason: "reissue://" + upgraded.absoluteString)
                }
            }
        }
        return .allow
    }
    public func decideResource(_ ctx: ResourceContext) async -> PolicyDecision? { nil }
    public func decidePrivacy(_ ctx: PrivacyContext) async -> PolicyDecision? { nil }
}
