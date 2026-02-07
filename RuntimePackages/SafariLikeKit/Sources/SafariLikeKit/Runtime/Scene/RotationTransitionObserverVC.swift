import UIKit
import SafariLikeCoreKit

/// Observes UIKit rotation/size transition lifecycle for a window-scene and informs `SceneMetrics`.
///
/// Goal: prevent committing "stable" metrics during rotation and only commit after the transition
/// has settled (post-rotation layout passes + consecutive sane samples).
@MainActor
final class RotationTransitionObserverVC: UIViewController {
    private let metrics: SceneMetrics

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

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        metrics.rotationWillBegin()
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self else { return }
            self.metrics.rotationDidEnd()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        metrics.noteLayoutPass()
    }
}
