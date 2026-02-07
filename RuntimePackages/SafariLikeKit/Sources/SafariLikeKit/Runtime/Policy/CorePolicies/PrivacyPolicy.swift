import Foundation
import SafariLikeCoreKit
public struct PrivacyPolicy: PolicyProviding {
    public let id: String = "core.privacy"
    public let kind: PolicyProviderKind = .core
    public let priority: Int = 80
    public var thirdPartyCookiesAllowed: Bool = false
    public init() {}
    public func decideNavigation(_ ctx: NavigationContext) async -> PolicyDecision? { nil }
    public func decideResource(_ ctx: ResourceContext) async -> PolicyDecision? { nil }
    public func decidePrivacy(_ ctx: PrivacyContext) async -> PolicyDecision? {
        if ctx.isThirdParty, ctx.operation == .cookies, thirdPartyCookiesAllowed == false {
            return .cancel(reason: "third_party_cookies")
        }
        return .allow
    }
}
