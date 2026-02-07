import Combine

/// Minimal UI-owned split pane coordinator.
///
/// Layering:
/// - Lives in SafariLikeUIKit (UI glue).
/// - Does not depend on SafariLikeKit.
@MainActor
public final class SplitPaneCoordinator: ObservableObject {
    public enum SplitMode: Sendable, Equatable {
        case single
        case split
    }

    @Published public private(set) var splitMode: SplitMode = .single

    public init() {}

    public func enterSplitMode() {
        splitMode = .split
    }

    public func exitSplitMode() {
        splitMode = .single
    }
}
