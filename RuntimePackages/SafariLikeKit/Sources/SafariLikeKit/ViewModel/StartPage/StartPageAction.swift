import Foundation
import SafariLikeCoreKit
/// User intents on the native Start Page surface.
///
/// This is intentionally WebKit-free.
public enum StartPageAction: Equatable, Sendable {
    case submitQueryOrURLString(String)
    case openURLString(String)
    case openReadingListItem(id: UUID)
    case toggleSidebar
    case toggleRelated
    case presentTabOverview
    case newTab
    case goBack
    case goForward
    case reload
}
