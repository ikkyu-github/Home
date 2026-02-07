import Foundation
import BrowserCore

public enum RuntimeAttachmentState: String, Codable {
    case attached
    case detached
}

public struct TabState: Identifiable, Codable, Equatable {
    public let id: UUID
    public var url: URL?
    public var title: String?
    public var lastActiveAt: Date
    public var hasSnapshot: Bool
    public var lastSnapshotAt: Date?
    /// Lightweight snapshot image data (typically JPEG) captured when a tab becomes inactive.
    ///
    /// Stored as Data to keep `TabState` codable and cheap to pass through reducers.
    public var snapshotData: Data?
    public var isPrivate: Bool
    public var lifecycle: TabLifecycleState
    public var runtimeAttachment: RuntimeAttachmentState

    public struct ReaderState: Codable, Equatable {
        public var isReaderAvailable: Bool
        public var isReaderEnabled: Bool

        public init(isReaderAvailable: Bool = false, isReaderEnabled: Bool = false) {
            self.isReaderAvailable = isReaderAvailable
            self.isReaderEnabled = isReaderEnabled
        }
    }

    public var reader: ReaderState

    public init(
        id: UUID = UUID(),
        url: URL? = nil,
        title: String? = nil,
        lastActiveAt: Date = Date(),
        hasSnapshot: Bool = false,
        lastSnapshotAt: Date? = nil,
        snapshotData: Data? = nil,
        isPrivate: Bool = false,
        lifecycle: TabLifecycleState = .creating,
        runtimeAttachment: RuntimeAttachmentState = .detached,
        reader: ReaderState = .init()
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.lastActiveAt = lastActiveAt
        self.hasSnapshot = hasSnapshot
        self.lastSnapshotAt = lastSnapshotAt
        self.snapshotData = snapshotData
        self.isPrivate = isPrivate
        self.lifecycle = lifecycle
        self.runtimeAttachment = runtimeAttachment
        self.reader = reader
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case url
        case title
        case lastActiveAt
        case hasSnapshot
        case lastSnapshotAt
        case snapshotData
        case isPrivate
        case lifecycle
        case runtimeAttachment
        case reader
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(UUID.self, forKey: .id)
        self.url = try container.decodeIfPresent(URL.self, forKey: .url)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.lastActiveAt = try container.decodeIfPresent(Date.self, forKey: .lastActiveAt) ?? Date()
        self.hasSnapshot = try container.decodeIfPresent(Bool.self, forKey: .hasSnapshot) ?? false
        self.lastSnapshotAt = try container.decodeIfPresent(Date.self, forKey: .lastSnapshotAt)
        self.snapshotData = try container.decodeIfPresent(Data.self, forKey: .snapshotData)
        self.isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
        self.lifecycle = try container.decodeIfPresent(TabLifecycleState.self, forKey: .lifecycle) ?? .creating
        self.runtimeAttachment = try container.decodeIfPresent(RuntimeAttachmentState.self, forKey: .runtimeAttachment) ?? .detached
        self.reader = try container.decodeIfPresent(ReaderState.self, forKey: .reader) ?? .init()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encode(lastActiveAt, forKey: .lastActiveAt)
        try container.encode(hasSnapshot, forKey: .hasSnapshot)
        try container.encodeIfPresent(lastSnapshotAt, forKey: .lastSnapshotAt)
        try container.encodeIfPresent(snapshotData, forKey: .snapshotData)
        try container.encode(isPrivate, forKey: .isPrivate)
        try container.encode(lifecycle, forKey: .lifecycle)
        try container.encode(runtimeAttachment, forKey: .runtimeAttachment)
        try container.encode(reader, forKey: .reader)
    }

    public var isClosed: Bool { lifecycle == .closed }
}
