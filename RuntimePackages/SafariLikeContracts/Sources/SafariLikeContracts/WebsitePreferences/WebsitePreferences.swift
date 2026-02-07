import Foundation

/// Per-website user preferences and settings.
///
/// Lives in SafariLikeContracts so core/runtime and UI hosts can share a single
/// source of truth without importing each other.
public struct WebsitePreferences: Codable, Hashable, Identifiable {
    public let id: String
    public let domain: String

    public enum ReaderTheme: String, Codable, CaseIterable, Hashable {
        case system
        case light
        case dark
        case sepia

        public var displayName: String {
            switch self {
            case .system: "System"
            case .light: "Light"
            case .dark: "Dark"
            case .sepia: "Sepia"
            }
        }
    }

    public enum ReaderFontFamily: String, Codable, CaseIterable, Hashable {
        case system
        case serif
        case sansSerif
        case monospace

        public var displayName: String {
            switch self {
            case .system: "System"
            case .serif: "Serif"
            case .sansSerif: "Sans Serif"
            case .monospace: "Monospace"
            }
        }
    }

    public var zoom: Double = 1.0
    public var prefersDesktop: Bool = false

    public enum UserAgentMode: String, Codable, CaseIterable, Hashable {
        case mobile
        case desktop

        public var displayName: String {
            switch self {
            case .mobile: "Mobile"
            case .desktop: "Desktop"
            }
        }
    }

    public var userAgent: UserAgentMode = .mobile

    public enum PermissionSetting: String, Codable, CaseIterable, Hashable {
        case ask
        case allow
        case deny

        public var displayName: String {
            switch self {
            case .ask: "Ask"
            case .allow: "Allow"
            case .deny: "Deny"
            }
        }
    }

    public var cameraPermission: PermissionSetting = .ask
    public var microphonePermission: PermissionSetting = .ask
    public var locationPermission: PermissionSetting = .ask

    public var readerDefault: Bool = false
    public var readerFontSizePercent: Int = 100
    public var readerFontFamily: ReaderFontFamily = .system
    public var readerTheme: ReaderTheme = .system

    public var javaScriptEnabled: Bool = true
    public var allowsPopups: Bool = false
    public var allowsWindowOpen: Bool = true
    public var contentBlockerEnabled: Bool = true

    /// Per-site override for system Autofill UX.
    ///
    /// Notes:
    /// - This does not store credentials; it only gates whether the app should encourage
    ///   or assist Autofill features for this site.
    public var autofillEnabled: Bool = true

    public var contentBlockingEnabled: Bool {
        get { contentBlockerEnabled }
        set { contentBlockerEnabled = newValue }
    }

    public var allowsMediaAutoplay: Bool = false
    public var allowsAudioAutoplay: Bool = false
    public var blockCookies: Bool = false
    public var forceDoNotTrack: Bool = false

    public let createdAt: Date
    public private(set) var lastModifiedAt: Date

    public init(
        id: String? = nil,
        domain: String,
        createdAt: Date = Date()
    ) {
        self.id = id ?? domain
        self.domain = domain
        self.createdAt = createdAt
        self.lastModifiedAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case domain
        case zoom
        case prefersDesktop
        case userAgent
        case readerDefault
        case readerFontSizePercent
        case readerFontFamily
        case readerTheme
        case javaScriptEnabled
        case allowsPopups
        case allowsWindowOpen
        case contentBlockerEnabled
        case autofillEnabled
        case cameraPermission
        case microphonePermission
        case locationPermission
        case allowsMediaAutoplay
        case allowsAudioAutoplay
        case blockCookies
        case forceDoNotTrack
        case createdAt
        case lastModifiedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let domain = try container.decode(String.self, forKey: .domain)
        self.domain = domain
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? domain

        let createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.createdAt = createdAt
        self.lastModifiedAt = try container.decodeIfPresent(Date.self, forKey: .lastModifiedAt) ?? createdAt

        self.zoom = try container.decodeIfPresent(Double.self, forKey: .zoom) ?? 1.0
        self.prefersDesktop = try container.decodeIfPresent(Bool.self, forKey: .prefersDesktop) ?? false

        if let decodedUA = try container.decodeIfPresent(UserAgentMode.self, forKey: .userAgent) {
            self.userAgent = decodedUA
            self.prefersDesktop = (decodedUA == .desktop)
        } else {
            self.userAgent = self.prefersDesktop ? .desktop : .mobile
        }

        self.readerDefault = try container.decodeIfPresent(Bool.self, forKey: .readerDefault) ?? false

        self.readerFontSizePercent = try container.decodeIfPresent(Int.self, forKey: .readerFontSizePercent) ?? 100
        self.readerFontFamily = try container.decodeIfPresent(ReaderFontFamily.self, forKey: .readerFontFamily) ?? .system
        self.readerTheme = try container.decodeIfPresent(ReaderTheme.self, forKey: .readerTheme) ?? .system

        self.javaScriptEnabled = try container.decodeIfPresent(Bool.self, forKey: .javaScriptEnabled) ?? true
        self.allowsPopups = try container.decodeIfPresent(Bool.self, forKey: .allowsPopups) ?? false
        self.allowsWindowOpen = try container.decodeIfPresent(Bool.self, forKey: .allowsWindowOpen) ?? true
        self.contentBlockerEnabled = try container.decodeIfPresent(Bool.self, forKey: .contentBlockerEnabled) ?? true
        self.autofillEnabled = try container.decodeIfPresent(Bool.self, forKey: .autofillEnabled) ?? true

        self.cameraPermission = try container.decodeIfPresent(PermissionSetting.self, forKey: .cameraPermission) ?? .ask
        self.microphonePermission = try container.decodeIfPresent(PermissionSetting.self, forKey: .microphonePermission) ?? .ask
        self.locationPermission = try container.decodeIfPresent(PermissionSetting.self, forKey: .locationPermission) ?? .ask

        self.allowsMediaAutoplay = try container.decodeIfPresent(Bool.self, forKey: .allowsMediaAutoplay) ?? false
        self.allowsAudioAutoplay = try container.decodeIfPresent(Bool.self, forKey: .allowsAudioAutoplay) ?? false
        self.blockCookies = try container.decodeIfPresent(Bool.self, forKey: .blockCookies) ?? false
        self.forceDoNotTrack = try container.decodeIfPresent(Bool.self, forKey: .forceDoNotTrack) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(domain, forKey: .domain)

        try container.encode(zoom, forKey: .zoom)
        try container.encode(prefersDesktop, forKey: .prefersDesktop)
        try container.encode(userAgent, forKey: .userAgent)
        try container.encode(readerDefault, forKey: .readerDefault)

        try container.encode(readerFontSizePercent, forKey: .readerFontSizePercent)
        try container.encode(readerFontFamily, forKey: .readerFontFamily)
        try container.encode(readerTheme, forKey: .readerTheme)

        try container.encode(javaScriptEnabled, forKey: .javaScriptEnabled)
        try container.encode(allowsPopups, forKey: .allowsPopups)
        try container.encode(allowsWindowOpen, forKey: .allowsWindowOpen)
        try container.encode(contentBlockerEnabled, forKey: .contentBlockerEnabled)
        try container.encode(autofillEnabled, forKey: .autofillEnabled)

        try container.encode(cameraPermission, forKey: .cameraPermission)
        try container.encode(microphonePermission, forKey: .microphonePermission)
        try container.encode(locationPermission, forKey: .locationPermission)

        try container.encode(allowsMediaAutoplay, forKey: .allowsMediaAutoplay)
        try container.encode(allowsAudioAutoplay, forKey: .allowsAudioAutoplay)
        try container.encode(blockCookies, forKey: .blockCookies)
        try container.encode(forceDoNotTrack, forKey: .forceDoNotTrack)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastModifiedAt, forKey: .lastModifiedAt)
    }

    @discardableResult
    public mutating func markModified() -> Date {
        lastModifiedAt = Date()
        return lastModifiedAt
    }
}

public extension WebsitePreferences {
    static func defaults(for domain: String) -> WebsitePreferences {
        WebsitePreferences(domain: domain)
    }

    static func permissive(for domain: String) -> WebsitePreferences {
        var prefs = WebsitePreferences(domain: domain)
        prefs.allowsPopups = true
        prefs.allowsMediaAutoplay = true
        prefs.allowsAudioAutoplay = true
        prefs.blockCookies = false
        prefs.forceDoNotTrack = false
        return prefs
    }
}
