import Foundation

public typealias SessionJournalEventType = JournalEventType

public enum JournalEventType: Codable, Sendable, Equatable {
    // MARK: - Required (minimum)
    case appLaunched

    case windowCreated
    case windowClosed

    case paneCreated
    case paneSelected

    case tabCreated
    case tabClosed
    case tabSelected
    case tabReordered

    case navigationCommitted

    case tabPinned
    case tabMuted

    case renderPolicyChanged
    case snapshotCreated

    // MARK: - Legacy / extended (kept for backward compatibility)
    case sessionStarted

    case splitModeChanged
    case paneFocusChanged

    case tabMovedPane
    case tabSuspended
    case tabDiscarded

    case sidebarToggled
    case relatedToggled
    case overviewToggled

    case urlCommitted
    case policyDecision
    case restoreCompleted

    // Legacy aliases (kept for backward decode)
    case paneEnteredSplit
    case paneExitedSplit
    case paneFocused

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)

        switch raw {
        case "appLaunched": self = .appLaunched

        case "windowCreated": self = .windowCreated
        case "windowClosed": self = .windowClosed

        case "paneCreated": self = .paneCreated
        case "paneSelected": self = .paneSelected

        case "tabCreated": self = .tabCreated
        case "tabClosed": self = .tabClosed
        case "tabSelected": self = .tabSelected
        case "tabReordered": self = .tabReordered

        case "navigationCommitted": self = .navigationCommitted

        case "tabPinned": self = .tabPinned
        case "tabMuted": self = .tabMuted

        case "renderPolicyChanged": self = .renderPolicyChanged
        case "snapshotCreated": self = .snapshotCreated

        // Existing/legacy strings
        case "sessionStarted": self = .sessionStarted
        case "splitModeChanged": self = .splitModeChanged
        case "paneFocusChanged": self = .paneFocusChanged
        case "tabMovedPane": self = .tabMovedPane
        case "tabSuspended": self = .tabSuspended
        case "tabDiscarded": self = .tabDiscarded
        case "sidebarToggled": self = .sidebarToggled
        case "relatedToggled": self = .relatedToggled
        case "overviewToggled": self = .overviewToggled
        case "urlCommitted": self = .urlCommitted
        case "policyDecision": self = .policyDecision
        case "restoreCompleted": self = .restoreCompleted

        // Legacy aliases
        case "paneEnteredSplit": self = .paneEnteredSplit
        case "paneExitedSplit": self = .paneExitedSplit
        case "paneFocused": self = .paneFocused

        // Legacy synonym: treat as navigationCommitted.
        case "urlCommittedLegacy": self = .urlCommitted

        default:
            // Unknown future event: degrade to a no-op semantic.
            self = .appLaunched
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawString)
    }

    private var rawString: String {
        switch self {
        case .appLaunched: return "appLaunched"

        case .windowCreated: return "windowCreated"
        case .windowClosed: return "windowClosed"

        case .paneCreated: return "paneCreated"
        case .paneSelected: return "paneSelected"

        case .tabCreated: return "tabCreated"
        case .tabClosed: return "tabClosed"
        case .tabSelected: return "tabSelected"
        case .tabReordered: return "tabReordered"

        case .navigationCommitted: return "navigationCommitted"

        case .tabPinned: return "tabPinned"
        case .tabMuted: return "tabMuted"

        case .renderPolicyChanged: return "renderPolicyChanged"
        case .snapshotCreated: return "snapshotCreated"

        case .sessionStarted: return "sessionStarted"
        case .splitModeChanged: return "splitModeChanged"
        case .paneFocusChanged: return "paneFocusChanged"
        case .tabMovedPane: return "tabMovedPane"
        case .tabSuspended: return "tabSuspended"
        case .tabDiscarded: return "tabDiscarded"
        case .sidebarToggled: return "sidebarToggled"
        case .relatedToggled: return "relatedToggled"
        case .overviewToggled: return "overviewToggled"
        case .urlCommitted: return "urlCommitted"
        case .policyDecision: return "policyDecision"
        case .restoreCompleted: return "restoreCompleted"

        case .paneEnteredSplit: return "paneEnteredSplit"
        case .paneExitedSplit: return "paneExitedSplit"
        case .paneFocused: return "paneFocused"
        }
    }
}

public typealias SessionJournalEvent = JournalEvent

public struct JournalEventPayloadEnvelope: Codable, Sendable, Equatable {
    public static let currentVersion: Int = 1

    public var version: Int
    public var payload: JournalEventPayload

    public init(version: Int = JournalEventPayloadEnvelope.currentVersion, payload: JournalEventPayload) {
        self.version = version
        self.payload = payload
    }
}

public enum JournalEventPayload: Codable, Sendable, Equatable {
    case navigationCommitted(NavigationCommittedPayload)
    case tabReordered(TabReorderedPayload)
    case tabPinned(TabPinnedPayload)
    case tabMuted(TabMutedPayload)
    case renderPolicyChanged(RenderPolicyChangedPayload)
    case snapshotCreated(SnapshotCreatedPayload)

    public struct NavigationCommittedPayload: Codable, Sendable, Equatable {
        public var url: URL
        public var title: String?
        public var backForward: NavigationBackForwardSummary?

        public init(url: URL, title: String? = nil, backForward: NavigationBackForwardSummary? = nil) {
            self.url = url
            self.title = title
            self.backForward = backForward
        }
    }

    public struct NavigationBackForwardSummary: Codable, Sendable, Equatable {
        public var backCount: Int
        public var forwardCount: Int

        public init(backCount: Int, forwardCount: Int) {
            self.backCount = backCount
            self.forwardCount = forwardCount
        }
    }

    public struct TabReorderedPayload: Codable, Sendable, Equatable {
        public var fromIndex: Int
        public var toIndex: Int

        public init(fromIndex: Int, toIndex: Int) {
            self.fromIndex = fromIndex
            self.toIndex = toIndex
        }
    }

    public struct TabPinnedPayload: Codable, Sendable, Equatable {
        public var isPinned: Bool
        public init(isPinned: Bool) { self.isPinned = isPinned }
    }

    public struct TabMutedPayload: Codable, Sendable, Equatable {
        public var isMuted: Bool
        public init(isMuted: Bool) { self.isMuted = isMuted }
    }

    public struct RenderPolicyChangedPayload: Codable, Sendable, Equatable {
        public var maxConcurrentViews: Int
        public init(maxConcurrentViews: Int) { self.maxConcurrentViews = maxConcurrentViews }
    }

    public struct SnapshotCreatedPayload: Codable, Sendable, Equatable {
        public var snapshotID: UUID
        public var relativePath: String
        public var contentHash: String?

        public init(snapshotID: UUID, relativePath: String, contentHash: String? = nil) {
            self.snapshotID = snapshotID
            self.relativePath = relativePath
            self.contentHash = contentHash
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case navigationCommitted
        case tabReordered
        case tabPinned
        case tabMuted
        case renderPolicyChanged
        case snapshotCreated
    }

    private enum Kind: String, Codable {
        case navigationCommitted
        case tabReordered
        case tabPinned
        case tabMuted
        case renderPolicyChanged
        case snapshotCreated
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .navigationCommitted:
            self = .navigationCommitted(try c.decode(NavigationCommittedPayload.self, forKey: .navigationCommitted))
        case .tabReordered:
            self = .tabReordered(try c.decode(TabReorderedPayload.self, forKey: .tabReordered))
        case .tabPinned:
            self = .tabPinned(try c.decode(TabPinnedPayload.self, forKey: .tabPinned))
        case .tabMuted:
            self = .tabMuted(try c.decode(TabMutedPayload.self, forKey: .tabMuted))
        case .renderPolicyChanged:
            self = .renderPolicyChanged(try c.decode(RenderPolicyChangedPayload.self, forKey: .renderPolicyChanged))
        case .snapshotCreated:
            self = .snapshotCreated(try c.decode(SnapshotCreatedPayload.self, forKey: .snapshotCreated))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .navigationCommitted(let p):
            try c.encode(Kind.navigationCommitted, forKey: .kind)
            try c.encode(p, forKey: .navigationCommitted)
        case .tabReordered(let p):
            try c.encode(Kind.tabReordered, forKey: .kind)
            try c.encode(p, forKey: .tabReordered)
        case .tabPinned(let p):
            try c.encode(Kind.tabPinned, forKey: .kind)
            try c.encode(p, forKey: .tabPinned)
        case .tabMuted(let p):
            try c.encode(Kind.tabMuted, forKey: .kind)
            try c.encode(p, forKey: .tabMuted)
        case .renderPolicyChanged(let p):
            try c.encode(Kind.renderPolicyChanged, forKey: .kind)
            try c.encode(p, forKey: .renderPolicyChanged)
        case .snapshotCreated(let p):
            try c.encode(Kind.snapshotCreated, forKey: .kind)
            try c.encode(p, forKey: .snapshotCreated)
        }
    }
}

public struct JournalEvent: Codable, Sendable, Equatable, Identifiable {
    public static let currentSchemaVersion: Int = 3

    public var schemaVersion: Int

    public var id: UUID
    public var ts: Date

    public var type: JournalEventType
    public var windowID: String
    public var paneID: String?
    public var tabID: UUID?

    // Legacy/simple fields (kept for compatibility with existing writers/replayers)
    public var url: String?
    public var details: String?

    // New structured payload (optional)
    public var payload: JournalEventPayloadEnvelope?

    public init(
        type: JournalEventType,
        timestamp: Date = Date(),
        windowID: String,
        paneID: String? = nil,
        tabID: UUID? = nil,
        url: String? = nil,
        details: String? = nil,
        payload: JournalEventPayloadEnvelope? = nil,
        eventID: UUID = UUID(),
        schemaVersion: Int = JournalEvent.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.id = eventID
        self.ts = timestamp
        self.type = type
        self.windowID = windowID
        self.paneID = paneID
        self.tabID = tabID
        self.url = url
        self.details = details
        self.payload = payload
    }

    // Compatibility shims for existing BrowserCore callers.
    public var eventID: UUID {
        get { id }
        set { id = newValue }
    }

    public var createdAt: Date {
        get { ts }
        set { ts = newValue }
    }

    public var timestamp: Date {
        get { ts }
        set { ts = newValue }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion

        // New canonical keys
        case id
        case ts

        case type
        case windowID
        case paneID
        case tabID
        case url
        case details
        case payload

        // Legacy keys
        case eventID
        case createdAt
        case timestamp
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.schemaVersion = (try? c.decode(Int.self, forKey: .schemaVersion)) ?? 1

        if let id = try? c.decode(UUID.self, forKey: .id) {
            self.id = id
        } else if let legacyID = try? c.decode(UUID.self, forKey: .eventID) {
            self.id = legacyID
        } else {
            self.id = UUID()
        }

        let decodedTS: Date
        if let ts = try? c.decode(Date.self, forKey: .ts) {
            decodedTS = ts
        } else if let createdAt = try? c.decode(Date.self, forKey: .createdAt) {
            decodedTS = createdAt
        } else if let legacy = try? c.decode(Date.self, forKey: .timestamp) {
            decodedTS = legacy
        } else {
            decodedTS = Date(timeIntervalSince1970: 0)
        }
        self.ts = decodedTS

        self.type = (try? c.decode(JournalEventType.self, forKey: .type)) ?? .appLaunched
        self.windowID = (try? c.decode(String.self, forKey: .windowID)) ?? "default"
        self.paneID = try? c.decode(String.self, forKey: .paneID)
        self.tabID = try? c.decode(UUID.self, forKey: .tabID)
        self.url = try? c.decode(String.self, forKey: .url)
        self.details = try? c.decode(String.self, forKey: .details)
        self.payload = try? c.decode(JournalEventPayloadEnvelope.self, forKey: .payload)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)

        // Canonical keys
        try c.encode(id, forKey: .id)
        try c.encode(ts, forKey: .ts)

        // Legacy keys for backward readers.
        try c.encode(id, forKey: .eventID)
        try c.encode(ts, forKey: .createdAt)
        try c.encode(ts, forKey: .timestamp)

        try c.encode(type, forKey: .type)
        try c.encode(windowID, forKey: .windowID)
        try c.encodeIfPresent(paneID, forKey: .paneID)
        try c.encodeIfPresent(tabID, forKey: .tabID)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encodeIfPresent(details, forKey: .details)
        try c.encodeIfPresent(payload, forKey: .payload)
    }
}
