import Foundation

public struct PluginDescriptor: Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let version: String
    public let author: String
    public let kind: PluginKind

    public init(
        id: String,
        name: String,
        version: String,
        author: String,
        kind: PluginKind
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.author = author
        self.kind = kind
    }
}

public enum PluginKind: Hashable, Sendable {
    case policy
    case feature
    case content
}

public enum PluginLifecycleState: Sendable {
    case unloaded
    case loaded
    case enabled
    case disabled
    case failed(Error)
}
