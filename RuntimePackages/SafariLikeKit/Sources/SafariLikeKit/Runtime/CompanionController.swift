import SwiftUI
import Combine
import SafariLikeCoreKit
final class CompanionController: ObservableObject {
    @Published var relatedPresentation: RelatedPresentation = .hidden
    @Published var relatedAnimation: Animation? = nil
    init(collapsedFraction: CGFloat = 0.33, snapMid: CGFloat = CompanionConstants.snapMid) {
        _ = collapsedFraction
        _ = snapMid
    }
    var isLandscapeDevice: Bool = false
    var isAutoCompanionEnabled: Bool = false
    var didUserOverrideCompanionVisibility: Bool = false
    private var isItemsEmpty: Bool = true
    // MARK: - Public API
    func applyOrientationRule(isLandscape: Bool) {
        isLandscapeDevice = isLandscape
        recomputePresentationIfNeeded()
    }
    func updateCompanionItems(empty: Bool) {
        isItemsEmpty = empty
        recomputePresentationIfNeeded()
    }
    func setPresentation(_ presentation: RelatedPresentation) {
        relatedPresentation = presentation
    }
    // MARK: - Internal Logic
    private func recomputePresentationIfNeeded() {
        // Respect explicit user action
        guard didUserOverrideCompanionVisibility == false else { return }
        // Auto policy disabled → hide
        guard isAutoCompanionEnabled else {
            relatedPresentation = .hidden
            return
        }
        // No items → hide
        guard isItemsEmpty == false else {
            relatedPresentation = .hidden
            return
        }
        // Auto decision
        // Architectural rule: Related must never reserve width from the WebView.
        // Landscape must use an overlay presenter (RelatedChromeState + RelatedOverlayPane),
        // not a split-style layout.
        relatedPresentation = .portraitPopup(heightFraction: CompanionConstants.snapMid)
    }
}
