import SafariLikeCoreKit
enum TabManagerError: Error, Equatable, Sendable {
    case unknown
    case networkError(String)
    case invalidTab
    case permissionDenied
    // ... add other error cases as needed
}
