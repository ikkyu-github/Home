import Foundation
import SafariLikeContracts

public enum WebsiteDataServiceError: Error, Sendable, Equatable {
    case unsupportedProfile
}

/// BrowserCore protocol boundary for website data management.
///
/// Implementations live in platform/runtime layers (e.g. SafariLikeCoreKit via WebKit).
public protocol WebsiteDataServicing: Sendable {
    /// Enumerate website data records.
    func fetchRecords(profile: WebsiteDataProfile) async throws -> [WebsiteDataRecord]

    /// Clear website data for the given request.
    func clear(request: ClearWebsiteDataRequest) async throws

    /// Returns the set of data types supported by the runtime adapter.
    func supportedDataTypes(profile: WebsiteDataProfile) async -> Set<WebsiteDataType>
}
