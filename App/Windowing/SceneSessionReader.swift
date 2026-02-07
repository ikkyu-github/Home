import SwiftUI
import Combine
import UIKit

/// Reads the underlying `UISceneSession` for the current SwiftUI scene.
///
/// SwiftUI does not expose `UISceneSession` directly via `@Environment`, so we bridge
/// via a tiny `UIViewControllerRepresentable` and plumb the session to the caller.
struct SceneSessionReader: UIViewControllerRepresentable {
    typealias UIViewControllerType = SceneSessionReaderViewController

    let onResolve: (UISceneSession) -> Void

    func makeUIViewController(context: Context) -> SceneSessionReaderViewController {
        SceneSessionReaderViewController(onResolve: onResolve)
    }

    func updateUIViewController(_ uiViewController: SceneSessionReaderViewController, context: Context) {
        uiViewController.onResolve = onResolve
        uiViewController.attemptResolveIfPossible()
    }
}

final class SceneSessionReaderViewController: UIViewController {
    var onResolve: (UISceneSession) -> Void

    private var didResolve: Bool = false

    init(onResolve: @escaping (UISceneSession) -> Void) {
        self.onResolve = onResolve
        super.init(nibName: nil, bundle: nil)
        view.isHidden = true
        view.isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        attemptResolveIfPossible()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        attemptResolveIfPossible()
    }

    func attemptResolveIfPossible() {
        guard didResolve == false else { return }
        guard let session = view.window?.windowScene?.session else { return }
        didResolve = true

        // Ensure the callback doesn't mutate SwiftUI state during layout.
        Task { @MainActor [onResolve] in
            await Task.yield()
            onResolve(session)
        }
    }
}


/// Reads scene metrics from the real UIWindow/UIScene lifecycle.
///
/// This avoids relying on GeometryReader during rotation, where safe area values
/// can be transiently incorrect.
