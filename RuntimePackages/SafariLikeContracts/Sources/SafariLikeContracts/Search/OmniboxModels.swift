import Foundation

public enum OmniboxResolvedKind: String, Codable, Sendable {
    case url
    case search
}

/// Result of resolving a user omnibox input into a concrete navigation target.
public struct OmniboxResolvedInput: Codable, Hashable, Sendable {
    public var original: String
    public var resolvedURLString: String
    public var kind: OmniboxResolvedKind

    public init(original: String, resolvedURLString: String, kind: OmniboxResolvedKind) {
        self.original = original
        self.resolvedURLString = resolvedURLString
        self.kind = kind
    }
}
