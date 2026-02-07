import Foundation
import Combine

/// Protocol surface for the UIKit/SwiftUI bridge to report "reality" snapshots
/// without knowing about the concrete `TabWebStore` type.
@MainActor
public protocol WebViewRealityUpdating: AnyObject {
    func updateReality(_ snapshot: WebViewRealitySnapshot)
}

/// Protocol surface for lifecycle code to observe reality + restore state
/// without binding to the concrete `TabWebStore` type.
@MainActor
public protocol WebViewRealityObserving: AnyObject {
    var webViewRealityPublisher: AnyPublisher<WebViewRealitySnapshot?, Never> { get }
    var uxRestoreStatePublisher: AnyPublisher<UXRestoreController.State, Never> { get }

    var currentWebViewReality: WebViewRealitySnapshot? { get }
    var currentUXRestoreState: UXRestoreController.State { get }
}

public typealias WebViewRealityCoordinating = WebViewRealityUpdating & WebViewRealityObserving
