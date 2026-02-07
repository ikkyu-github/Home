import Foundation
import SafariLikeContracts

/// Single source of truth for URL canonicalization in BrowserCore.
public struct URLStringNormalizer: Sendable {
    public init() {}

    public func canonicalize(_ urlString: String) -> CanonicalURL? {
        CanonicalURL(string: urlString)
    }

    public func canonicalString(_ urlString: String) -> String? {
        canonicalize(urlString)?.normalized
    }
}
