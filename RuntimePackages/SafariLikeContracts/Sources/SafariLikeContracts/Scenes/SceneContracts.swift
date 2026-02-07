import Foundation

/// Stable identity for a UI scene/window.
///
/// - `sceneID` should typically be backed by `UISceneSession.persistentIdentifier`.
/// - `windowID` is an app-owned stable UUID when you have an explicit BrowserWindow concept.
public struct SceneIdentity: Codable, Sendable, Hashable {
    public var sceneID: String
    public var windowID: UUID?

    public init(sceneID: String, windowID: UUID? = nil) {
        self.sceneID = sceneID
        self.windowID = windowID
    }
}

/// Lightweight per-scene summary used for "Continue Browsing" style suggestions.
///
/// Privacy:
/// - Producers must not persist private-browsing URLs.
public struct SceneSessionSummary: Codable, Sendable, Hashable {
    public var identity: SceneIdentity
    public var selectedURL: URL?
    public var selectedTitle: String?
    public var tabCount: Int
    public var updatedAt: Date

    public init(
        identity: SceneIdentity,
        selectedURL: URL?,
        selectedTitle: String?,
        tabCount: Int,
        updatedAt: Date = Date()
    ) {
        self.identity = identity
        self.selectedURL = selectedURL
        self.selectedTitle = selectedTitle
        self.tabCount = tabCount
        self.updatedAt = updatedAt
    }
}

/// Serializable cross-scene requests.
///
/// This is intentionally URL/state-only; it must never contain WebKit objects.
public enum CrossSceneIntent: Codable, Sendable, Hashable {
    case openURL(url: URL, preferNewScene: Bool)

    private enum CodingKeys: String, CodingKey {
        case type
        case url
        case preferNewScene
    }

    private enum Kind: String, Codable {
        case openURL
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .type)
        switch kind {
        case .openURL:
            let url = try container.decode(URL.self, forKey: .url)
            let preferNewScene = try container.decode(Bool.self, forKey: .preferNewScene)
            self = .openURL(url: url, preferNewScene: preferNewScene)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .openURL(url, preferNewScene):
            try container.encode(Kind.openURL, forKey: .type)
            try container.encode(url, forKey: .url)
            try container.encode(preferNewScene, forKey: .preferNewScene)
        }
    }
}
