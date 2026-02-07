import SwiftUI
import UIKit

/// Reads scene metrics from the real UIWindow/UIScene lifecycle.
///
/// This avoids relying on GeometryReader during rotation, where safe area values
/// can be transiently incorrect.
struct SceneMetricsReader: UIViewControllerRepresentable {

    let metrics: SceneMetrics

    func makeUIViewController(context: Context) -> UIViewController {
        MetricsViewController(metrics: metrics)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    private final class MetricsViewController: UIViewController {
        let metrics: SceneMetrics

        init(metrics: SceneMetrics) {
            self.metrics = metrics
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()

            let size = view.window?.bounds.size ?? view.bounds.size
            let insets = view.window?.safeAreaInsets ?? .zero
            let orientation = view.window?.windowScene?.interfaceOrientation ?? .unknown

            metrics.update(size: size, insets: insets, orientation: orientation)
        }
    }
}
