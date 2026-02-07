import SwiftUI
import SafariLikeCoreKit

/// SwiftUI wrapper that installs `RotationTransitionObserverVC` into the view tree.
///
/// Place this at the scene root so it receives UIKit rotation callbacks.
public struct RotationTransitionObserverView: UIViewControllerRepresentable {
    public let metrics: SceneMetrics

    public init(metrics: SceneMetrics) {
        self.metrics = metrics
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        RotationTransitionObserverVC(metrics: metrics)
    }

    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
