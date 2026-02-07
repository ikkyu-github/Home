import Foundation
import Combine
import UIKit
import SafariLikeCoreKit
@MainActor
public final class SplitPaneCoordinator: ObservableObject {
    public let windowID: String
    @Published public private(set) var splitMode: SplitMode
    @Published public private(set) var primaryPaneState: PaneState
    @Published public private(set) var secondaryPaneState: PaneState
    @Published public private(set) var focusedPane: PaneID
    public init(windowID: String) {
        self.windowID = windowID
        self.splitMode = .single
        self.primaryPaneState = PaneState(
            paneID: .primary,
            activeTabID: nil,
            visible: true,
            widthFraction: 1.0,
            isPinned: true
        )
        self.secondaryPaneState = PaneState(
            paneID: .secondary,
            activeTabID: nil,
            visible: false,
            widthFraction: 0.0,
            isPinned: false
        )
        self.focusedPane = .primary
    }
    public func enterSplitMode() {
        splitMode = .split
        primaryPaneState.visible = true
        secondaryPaneState.visible = true
        // Default sizing: Safari-like 50/50.
        primaryPaneState.widthFraction = 0.5
        secondaryPaneState.widthFraction = 0.5
        // Keep focus stable; default to primary.
        if focusedPane != .primary {
            focusedPane = .primary
        }
        postFocusChanged()
    }
    public func exitSplitMode() {
        splitMode = .single
        focusedPane = .primary
        primaryPaneState.visible = true
        primaryPaneState.widthFraction = 1.0
        secondaryPaneState.visible = false
        secondaryPaneState.widthFraction = 0.0
        postFocusChanged()
    }
    public func focusPane(_ paneID: PaneID) {
        guard splitMode == .split else {
            focusedPane = .primary
            postFocusChanged()
            return
        }
        focusedPane = paneID
        postFocusChanged()
    }
    public func moveTab(_ tabID: UUID, to paneID: PaneID) {
        guard splitMode == .split else {
            primaryPaneState.activeTabID = tabID
            focusedPane = .primary
            postFocusChanged()
            return
        }
        switch paneID {
        case .primary:
            primaryPaneState.activeTabID = tabID
            focusedPane = .primary
        case .secondary:
            secondaryPaneState.activeTabID = tabID
            focusedPane = .secondary

        @unknown default:
            primaryPaneState.activeTabID = tabID
            focusedPane = .primary
        }
        postFocusChanged()
    }
    // MARK: - Policy helpers
    /// Secondary pane cannot auto-open external schemes.
    public func canAutoOpenExternalSchemes(in paneID: PaneID) -> Bool {
        switch paneID {
        case .primary:
            return true
        case .secondary:
            return false

        @unknown default:
            return true
        }
    }
    /// Background pane reduces activity priority.
    public func isBackgroundPane(_ paneID: PaneID) -> Bool {
        splitMode == .split && focusedPane != paneID
    }
    private func postFocusChanged() {
        NotificationCenter.default.post(
            name: .splitPaneFocusChanged,
            object: self,
            userInfo: [
                "windowID": windowID,
                "focusedPane": focusedPane.rawValue,
                "splitMode": splitMode.rawValue
            ]
        )
    }
}
public extension Notification.Name {
    static let splitPaneFocusChanged = Notification.Name("SafariLike.splitPane.focusChanged")
}
