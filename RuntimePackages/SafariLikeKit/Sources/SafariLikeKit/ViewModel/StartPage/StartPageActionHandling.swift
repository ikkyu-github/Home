import Foundation
import SafariLikeCoreKit
/// Start Page command sink.
///
/// Implementations typically bridge into the window's SplitBrowserViewModel + chrome UI state.
/// This protocol is `@MainActor` because these actions ultimately mutate UI-bound state.
@MainActor
public protocol StartPageActionHandling {
    func handle(_ action: StartPageAction)
}
