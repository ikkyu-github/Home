import Foundation
import SafariLikeCoreKit
/// Policy for gating live Related rendering.
///
/// This does not decide presentation style (sidebar vs popup) and does not decide visibility.
internal enum RelatedPolicy {
    struct Input: Equatable {
        let isInOverview: Bool
        let hasActiveTab: Bool
        init(isInOverview: Bool, hasActiveTab: Bool) {
            self.isInOverview = isInOverview
            self.hasActiveTab = hasActiveTab
        }
    }
    static func allowsLiveRelated(for input: Input) -> Bool {
        // SPEC:
        // - Allow live related only when:
        //   - not in overview
        //   - has an active tab
        return input.isInOverview == false && input.hasActiveTab
    }
}
