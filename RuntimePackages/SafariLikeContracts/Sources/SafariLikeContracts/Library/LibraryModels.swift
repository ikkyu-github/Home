import Foundation

// MARK: - Profile

/// Library profile for privacy/persistence boundaries.
///
/// Note: Named differently than `SafariLikeCoreKit.BrowsingProfile` to avoid
/// cross-module symbol collisions.
public enum LibraryProfile: String, Codable, Sendable {
    case regular
    case `private`
}

// MARK: - Canonical URL

/// Canonicalized URL representation used across history/bookmarks/top-sites/suggestions.
///
/// Notes:
/// - Best-effort normalization intended to be deterministic and stable.
/// - This does *not* attempt tracker stripping or PSL-accurate eTLD+1.
public struct CanonicalURL: Codable, Hashable, Sendable {
    public let normalized: String
    public let scheme: String
    public let host: String
    public let path: String
    public let query: String?

    public var url: URL? { URL(string: normalized) }

    /// Best-effort domain key used for grouping (eTLD+1 approximation or host).
    public var domainKey: String { SiteKey(host: host).storageKey }

    public init?(string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // If missing scheme, assume https for canonicalization (common Safari behavior when users type).
        let hasScheme = trimmed.range(of: "^[a-zA-Z][a-zA-Z0-9+.-]*://", options: .regularExpression) != nil
        let candidate = hasScheme ? trimmed : "https://\(trimmed)"

        guard var components = URLComponents(string: candidate) else { return nil }
        guard let schemeRaw = components.scheme?.lowercased(), (schemeRaw == "http" || schemeRaw == "https") else {
            return nil
        }
        guard let hostRaw = components.host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !hostRaw.isEmpty else {
            return nil
        }

        // Force normalized scheme/host into the rendered URL string.
        components.scheme = schemeRaw
        components.host = hostRaw

        // Strip fragment.
        components.fragment = nil

        // Normalize default ports.
        if (schemeRaw == "http" && components.port == 80) || (schemeRaw == "https" && components.port == 443) {
            components.port = nil
        }

        // Normalize path.
        let p = (components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath)
        components.percentEncodedPath = p

        // Normalize empty query.
        if let q = components.percentEncodedQuery, q.isEmpty {
            components.percentEncodedQuery = nil
        }

        guard let normalizedURLString = components.string else { return nil }

        self.normalized = normalizedURLString
        self.scheme = schemeRaw
        self.host = hostRaw
        self.path = components.percentEncodedPath
        self.query = components.percentEncodedQuery
    }
}

// MARK: - History

public struct HistoryEntry: Codable, Hashable, Sendable, Identifiable {
    public var id: String { url.normalized }

    public let url: CanonicalURL
    public var title: String
    public var visitCount: Int
    public var lastVisitedAt: Date
    public var firstVisitedAt: Date

    public var domainKey: String { url.domainKey }

    public init(
        url: CanonicalURL,
        title: String,
        visitCount: Int,
        lastVisitedAt: Date,
        firstVisitedAt: Date
    ) {
        self.url = url
        self.title = title
        self.visitCount = visitCount
        self.lastVisitedAt = lastVisitedAt
        self.firstVisitedAt = firstVisitedAt
    }
}

// MARK: - Bookmarks

public enum BookmarkNodeType: String, Codable, Sendable {
    case folder
    case bookmark
}

public struct BookmarkNode: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public var type: BookmarkNodeType
    public var title: String
    public var url: CanonicalURL?
    public var parentID: UUID?
    public var orderIndex: Int
    public var isFavorite: Bool

    public init(
        id: UUID = UUID(),
        type: BookmarkNodeType,
        title: String,
        url: CanonicalURL? = nil,
        parentID: UUID? = nil,
        orderIndex: Int,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.url = url
        self.parentID = parentID
        self.orderIndex = orderIndex
        self.isFavorite = isFavorite
    }
}

// MARK: - Reading List

public struct ReadingListItem: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public var url: CanonicalURL
    public var title: String
    public var addedAt: Date
    public var isRead: Bool
    public var lastOpenedAt: Date?
    public var isOfflineAvailable: Bool

    public init(
        id: UUID = UUID(),
        url: CanonicalURL,
        title: String,
        addedAt: Date = Date(),
        isRead: Bool = false,
        lastOpenedAt: Date? = nil,
        isOfflineAvailable: Bool = false
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.addedAt = addedAt
        self.isRead = isRead
        self.lastOpenedAt = lastOpenedAt
        self.isOfflineAvailable = isOfflineAvailable
    }
}

// MARK: - Top Sites

public struct TopSite: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public var url: CanonicalURL
    public var title: String?
    public var score: Double
    public var isPinned: Bool
    public var orderIndex: Int?

    public init(
        id: UUID = UUID(),
        url: CanonicalURL,
        title: String? = nil,
        score: Double,
        isPinned: Bool,
        orderIndex: Int? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.score = score
        self.isPinned = isPinned
        self.orderIndex = orderIndex
    }
}

// MARK: - Suggestions

public enum SuggestionItemType: String, Codable, Sendable {
    case tab
    case history
    case bookmark
    case readingList
    case topSite
}

public struct SuggestionItem: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public var type: SuggestionItemType
    public var title: String
    public var subtitle: String
    public var url: CanonicalURL
    public var iconToken: String
    public var rankScore: Double

    public init(
        type: SuggestionItemType,
        title: String,
        subtitle: String,
        url: CanonicalURL,
        iconToken: String,
        rankScore: Double
    ) {
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.url = url
        self.iconToken = iconToken
        self.rankScore = rankScore
        self.id = "\(type.rawValue)|\(url.normalized)"
    }
}

// MARK: - Clear Data

public enum ClearDataTimeRange: String, Codable, Sendable {
    case lastHour
    case today
    case todayAndYesterday
    case allTime
}

public struct ClearDataOptions: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let history = ClearDataOptions(rawValue: 1 << 0)
    public static let bookmarks = ClearDataOptions(rawValue: 1 << 1)
    public static let readingList = ClearDataOptions(rawValue: 1 << 2)
    public static let topSites = ClearDataOptions(rawValue: 1 << 3)
    public static let downloadsList = ClearDataOptions(rawValue: 1 << 4)
    public static let siteSettings = ClearDataOptions(rawValue: 1 << 5)
    public static let websiteData = ClearDataOptions(rawValue: 1 << 6) // cookies/cache; non-domain in CoreKit

    public static let all: ClearDataOptions = [history, bookmarks, readingList, topSites, downloadsList, siteSettings, websiteData]
}
