import Foundation
import SafariLikeCoreKit
/// A unique identifier for a browser window in multi-scene session management.
///
/// This type wraps a UUID to provide type safety and semantic clarity
/// when referring to specific browser windows.
public struct BrowserWindowID: Hashable, Codable {
    /// The underlying UUID value
    public let value: UUID
    /// Creates a new browser window ID with a generated UUID
    public init() {
        self.value = UUID()
    }
    /// Creates a browser window ID from an existing UUID
    /// - Parameter uuid: The UUID to use as the window identifier
    public init(_ uuid: UUID) {
        self.value = uuid
    }
    // MARK: - Codable Conformance
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let uuid = try container.decode(UUID.self)
        self.value = uuid
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
    // MARK: - Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
    public static func == (lhs: BrowserWindowID, rhs: BrowserWindowID) -> Bool {
        lhs.value == rhs.value
    }
}
