import Foundation

public struct ReaderContentModel: Codable, Hashable, Sendable {
    public var title: String
    public var byline: String?
    public var textBlocks: [String]
    public var mainImageURL: URL?

    public init(
        title: String,
        byline: String? = nil,
        textBlocks: [String],
        mainImageURL: URL? = nil
    ) {
        self.title = title
        self.byline = byline
        self.textBlocks = textBlocks
        self.mainImageURL = mainImageURL
    }
}
