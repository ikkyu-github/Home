import Combine
import SwiftUI
import SafariLikeCoreKit
/// Window-scoped UI chrome state for the Related surface.
///
/// - Important: This is intentionally separate from `SplitBrowserViewModel`.
///   It must not be reset by tab/pane/navigation/orientation changes.
@MainActor
public final class RelatedChromeState: ObservableObject {
    @Published public var isVisible: Bool = false
    public init() {}
    public func toggle(animation: Animation? = .easeOut(duration: 0.25)) {
        setVisible(!isVisible, animation: animation)
    }
    public func setVisible(_ visible: Bool, animation: Animation? = .easeOut(duration: 0.25)) {
        if let animation {
            withAnimation(animation) {
                isVisible = visible
            }
        } else {
            isVisible = visible
        }
    }
}
