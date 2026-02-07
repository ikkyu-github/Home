import SwiftUI
import SafariLikeContracts

private struct SafariLikeSceneCommandHandlerKey: FocusedValueKey {
    typealias Value = (AppCommand) -> Void
}

public extension FocusedValues {
    /// Scene-local command handler used by `SafariLikeBrowserCommands`.
    var safariLikeSceneCommandHandler: ((AppCommand) -> Void)? {
        get { self[SafariLikeSceneCommandHandlerKey.self] }
        set { self[SafariLikeSceneCommandHandlerKey.self] = newValue }
    }
}
