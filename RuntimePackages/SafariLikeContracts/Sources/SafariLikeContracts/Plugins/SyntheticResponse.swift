import Foundation

/// Synthetic response used when plugins choose to handle a navigation
/// themselves instead of letting WebKit load the requested URL.
public struct SyntheticResponse: Sendable {
    public let mimeType: String
    public let data: Data
    public let statusCode: Int

    public init(
        mimeType: String,
        data: Data,
        statusCode: Int = 200
    ) {
        self.mimeType = mimeType
        self.data = data
        self.statusCode = statusCode
    }
}
