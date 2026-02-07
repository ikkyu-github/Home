import Foundation
import SafariLikeCoreKit
public struct PluginCapabilities: OptionSet, Sendable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }
    public static let observeNavigation = PluginCapabilities(rawValue: 1 << 0)
    public static let proposeNavigationDecision = PluginCapabilities(rawValue: 1 << 1)
    public static let observeResources = PluginCapabilities(rawValue: 1 << 2)
    public static let proposeResourceDecision = PluginCapabilities(rawValue: 1 << 3)
    public static let proposePrivacyDecision = PluginCapabilities(rawValue: 1 << 4)
    public static let uiOverlay = PluginCapabilities(rawValue: 1 << 5)
    public static let storageAccess = PluginCapabilities(rawValue: 1 << 6)
}
