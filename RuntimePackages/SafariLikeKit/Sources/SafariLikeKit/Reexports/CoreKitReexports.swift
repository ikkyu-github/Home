import Foundation
import SafariLikeCoreKit
// MARK: - Policies
public typealias PolicyCenter = SafariLikeCoreKit.PolicyCenter
public typealias PolicyProviding = SafariLikeCoreKit.PolicyProviding
public typealias PolicyProviderKind = SafariLikeCoreKit.PolicyProviderKind
public typealias PolicyEvent = SafariLikeCoreKit.PolicyEvent
public typealias PolicyDecision = SafariLikeCoreKit.PolicyDecision
public typealias PolicyMutation = SafariLikeCoreKit.PolicyMutation
public typealias NavigationContext = SafariLikeCoreKit.NavigationContext
public typealias ResourceContext = SafariLikeCoreKit.ResourceContext
public typealias PrivacyContext = SafariLikeCoreKit.PrivacyContext
public typealias NavigationType = SafariLikeCoreKit.NavigationType
public typealias ResourceType = SafariLikeCoreKit.ResourceType
public typealias PrivacyOperation = SafariLikeCoreKit.PrivacyOperation
// MARK: - Plugins
public typealias PluginCapability = SafariLikeCoreKit.PluginCapability
// MARK: - Content blocking
public typealias ContentBlockingProviding = SafariLikeCoreKit.ContentBlockingProviding
public typealias ContentBlockerList = SafariLikeCoreKit.ContentBlockerList
// MARK: - Chrome policy
public typealias ChromePolicy = SafariLikeCoreKit.ChromePolicy
// MARK: - Models
public typealias TabGroupColor = SafariLikeCoreKit.TabGroupColor
public typealias CompanionItem = SafariLikeCoreKit.CompanionItem
// MARK: - Related
public typealias RelatedLinkExtractor = SafariLikeCoreKit.RelatedLinkExtractor
// MARK: - Web
// Legacy WebViewConfigurationFactory has been deprecated in SafariLikeKit.
// Use SafariLikeCoreKit.WebViewConfigurationFactory as the single source of truth.
// This alias remains only to avoid widespread call-site churn.
typealias WebViewConfigurationFactory = SafariLikeCoreKit.WebViewConfigurationFactory
