import UIKit
import SafariLikeUXKit
import WebKit

@MainActor
extension WebView.Coordinator {
    func installGesturesIfNeeded(on webView: WKWebView) {
        // Gesture policy (including back/forward navigation gestures) is
        // configured by TabWebStore at WKWebView creation time.
        //
        // This hook is kept for compatibility with existing call sites
        // but intentionally performs no additional gesture setup.
        webView.allowsBackForwardNavigationGestures = true
    }

    func installFocusTapIfNeeded(on container: UIView) {
        guard focusTapRecognizer == nil else { return }
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleFocusTap))
        recognizer.cancelsTouchesInView = false
        container.addGestureRecognizer(recognizer)
        focusTapRecognizer = recognizer
    }

    func installEdgePanGesturesIfNeeded(on container: UIView) {
        guard edgePan == nil else { return }
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
        recognizer.delegate = self
        recognizer.cancelsTouchesInView = false
        container.addGestureRecognizer(recognizer)
        edgePan = recognizer
    }

    @objc func handleFocusTap() {
        onFocus?()
    }

    @objc func handleEdgePan(_ recognizer: UIPanGestureRecognizer) {
        guard let view = recognizer.view else { return }
        guard attachmentCoordinator.currentWebView != nil else { return }
        let width = max(1, view.bounds.width)
        let translationX = recognizer.translation(in: view).x
        switch recognizer.state {
        case .began:
            onFocus?()
            didCommitEdgeSwipe = false
            edgeProgress = 0
            if activeEdgeDirection == nil {
                let loc = recognizer.location(in: view)
                if loc.x <= edgeSwipePolicy.edgeZoneWidth {
                    activeEdgeDirection = .back
                } else if loc.x >= (width - edgeSwipePolicy.edgeZoneWidth) {
                    activeEdgeDirection = .forward
                }
            }
            if let direction = activeEdgeDirection {
                onEdgeSwipeProgress?(0, direction)
            }
        case .changed:
            guard let direction = activeEdgeDirection else { return }
            let signedDistance: CGFloat = {
                switch direction {
                case .back:
                    return max(0, translationX)
                case .forward:
                    return max(0, -translationX)
                }
            }()
            edgeProgress = min(1, max(0, signedDistance / width))
            onEdgeSwipeProgress?(edgeProgress, direction)
        case .ended, .cancelled, .failed:
            defer {
                if let direction = activeEdgeDirection {
                    onEdgeSwipeProgress?(0, direction)
                }
                activeEdgeDirection = nil
                edgeProgress = 0
                didCommitEdgeSwipe = false
            }
            guard didCommitEdgeSwipe == false else { return }
            guard let direction = activeEdgeDirection else { return }
            let velocityX = recognizer.velocity(in: view).x
            let shouldCommitByProgress = edgeProgress >= edgeSwipePolicy.commitProgressThreshold
            let shouldCommitByVelocity: Bool = {
                switch direction {
                case .back:
                    return velocityX >= edgeSwipePolicy.commitVelocityThreshold
                case .forward:
                    return velocityX <= -edgeSwipePolicy.commitVelocityThreshold
                }
            }()
            guard shouldCommitByProgress || shouldCommitByVelocity else { return }
            didCommitEdgeSwipe = true
            switch direction {
            case .back:
                onSwipeBack?()
            case .forward:
                onSwipeForward?()
            }
        default:
            break
        }
    }
}

@MainActor
extension WebView.Coordinator: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let view = gestureRecognizer.view else { return false }
        // Split-pane support: allow edge swipe only for the active pane when provided.
        if let isActivePane, isActivePane() == false {
            return false
        }
        if gestureRecognizer === edgePan {
            // Only enable when call sites provided navigation closures.
            let width = max(1, view.bounds.width)
            let loc = gestureRecognizer.location(in: view)
            let direction: WebView.EdgeSwipeDirection? = {
                if loc.x <= edgeSwipePolicy.edgeZoneWidth { return .back }
                if loc.x >= (width - edgeSwipePolicy.edgeZoneWidth) { return .forward }
                return nil
            }()
            guard let direction else { return false }
            switch direction {
            case .back:
                guard onSwipeBack != nil else { return false }
                if let canSwipeBack { guard canSwipeBack() else { return false } }
            case .forward:
                guard onSwipeForward != nil else { return false }
                if let canSwipeForward { guard canSwipeForward() else { return false } }
            }
            // Prefer horizontal intent; avoids fighting vertical scrolling.
            if let pan = gestureRecognizer as? UIPanGestureRecognizer {
                let v = pan.velocity(in: view)
                if abs(v.x) < abs(v.y) * edgeSwipePolicy.horizontalIntentRatio { return false }
            }
            activeEdgeDirection = direction
            return true
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Only allow simultaneous recognition with scrolling when the gesture
        // started inside the edge zone.
        guard let view = gestureRecognizer.view else { return false }
        let loc = gestureRecognizer.location(in: view)
        if gestureRecognizer === edgePan {
            return (loc.x <= edgeSwipePolicy.edgeZoneWidth) || (loc.x >= (view.bounds.width - edgeSwipePolicy.edgeZoneWidth))
        }
        return false
    }
}
