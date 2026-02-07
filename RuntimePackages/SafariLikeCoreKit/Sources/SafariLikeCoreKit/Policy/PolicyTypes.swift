import Foundation

public enum PolicyDecision: Sendable, Equatable {
    case allow
    case cancel(reason: String)
    case modify(PolicyMutation)
}

public struct PolicyMutation: Sendable, Equatable {
    public var headersToAdd: [String: String]
    public var headersToRemove: Set<String>
    public var userAgentOverride: String?
    public var referrerPolicyOverride: String?

    public init(
        headersToAdd: [String: String] = [:],
        headersToRemove: Set<String> = [],
        userAgentOverride: String? = nil,
        referrerPolicyOverride: String? = nil
    ) {
        self.headersToAdd = headersToAdd
        self.headersToRemove = headersToRemove
        self.userAgentOverride = userAgentOverride
        self.referrerPolicyOverride = referrerPolicyOverride
    }

    public var isEmpty: Bool {
        headersToAdd.isEmpty && headersToRemove.isEmpty && userAgentOverride == nil && referrerPolicyOverride == nil
    }
}

public enum NavigationType: String, Sendable, Codable {
    case link
    case formSubmit
    case backForward
    case reload
    case other
}

public struct NavigationContext: Sendable, Equatable {
    public let tabID: UUID
    public let windowID: String
    public let url: URL
    public let isMainFrame: Bool
    public let hasUserGesture: Bool
    public let navigationType: NavigationType
    public let sourceURL: URL?

    public init(
        tabID: UUID,
        windowID: String,
        url: URL,
        isMainFrame: Bool,
        hasUserGesture: Bool,
        navigationType: NavigationType,
        sourceURL: URL?
    ) {
        self.tabID = tabID
        self.windowID = windowID
        self.url = url
        self.isMainFrame = isMainFrame
        self.hasUserGesture = hasUserGesture
        self.navigationType = navigationType
        self.sourceURL = sourceURL
    }
}

public enum ResourceType: String, Sendable, Codable {
    case document
    case image
    case script
    case stylesheet
    case xhr
    case fetch
    case media
    case font
    case other
}

public struct ResourceContext: Sendable, Equatable {
    public let tabID: UUID
    public let windowID: String
    public let url: URL
    public let resourceType: ResourceType
    public let initiator: URL?
    public let isThirdParty: Bool

    public init(
        tabID: UUID,
        windowID: String,
        url: URL,
        resourceType: ResourceType,
        initiator: URL?,
        isThirdParty: Bool
    ) {
        self.tabID = tabID
        self.windowID = windowID
        self.url = url
        self.resourceType = resourceType
        self.initiator = initiator
        self.isThirdParty = isThirdParty
    }
}

public enum PrivacyOperation: String, Sendable, Codable {
    case cookies
    case localStorage
    case indexedDB
    case camera
    case microphone
    case geolocation
    case other
}

public struct PrivacyContext: Sendable, Equatable {
    public let tabID: UUID
    public let windowID: String
    public let url: URL
    public let operation: PrivacyOperation
    public let isThirdParty: Bool

    public init(
        tabID: UUID,
        windowID: String,
        url: URL,
        operation: PrivacyOperation,
        isThirdParty: Bool
    ) {
        self.tabID = tabID
        self.windowID = windowID
        self.url = url
        self.operation = operation
        self.isThirdParty = isThirdParty
    }
}
