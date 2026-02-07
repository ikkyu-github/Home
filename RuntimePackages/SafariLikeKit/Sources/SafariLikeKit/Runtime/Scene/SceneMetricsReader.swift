import Foundation
import Combine
import SwiftUI
import UIKit
import SafariLikeCoreKit
/// Reads scene metrics from the real UIWindow/UIScene lifecycle.
///
/// This avoids relying on GeometryReader during rotation, where safe area values
/// can be transiently incorrect.
public struct SceneMetricsReader: UIViewControllerRepresentable {
    public let metrics: SceneMetrics
    public init(metrics: SceneMetrics) {
        self.metrics = metrics
    }
    public func makeUIViewController(context: Context) -> UIViewController {
        MetricsViewController(metrics: metrics)
    }
    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    private final class MetricsViewController: UIViewController {
        let metrics: SceneMetrics
        private struct Snapshot {
            let width: CGFloat
            let height: CGFloat
            let top: CGFloat
            let left: CGFloat
            let bottom: CGFloat
            let right: CGFloat
            let orientationRawValue: Int
            func isApproximatelyEqual(to other: Snapshot, threshold: CGFloat) -> Bool {
                abs(width - other.width) <= threshold
                    && abs(height - other.height) <= threshold
                    && abs(top - other.top) <= threshold
                    && abs(left - other.left) <= threshold
                    && abs(bottom - other.bottom) <= threshold
                    && abs(right - other.right) <= threshold
                    && orientationRawValue == other.orientationRawValue
            }
            var size: CGSize { CGSize(width: width, height: height) }
            var insets: UIEdgeInsets { UIEdgeInsets(top: top, left: left, bottom: bottom, right: right) }
        }
        private var lastSent: Snapshot?
        private var pending: Snapshot?
        private var debounceTask: Task<Void, Never>?
        private var cancellables: Set<AnyCancellable> = []
        private let diffThreshold: CGFloat = 0.5
        private let debounceSeconds: TimeInterval = 0.05
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

            // If rotation begins, immediately cancel any queued debounced publish.
            metrics.$rotationInProgress
                .removeDuplicates()
                .sink { [weak self] inProgress in
                    guard let self else { return }
                    guard inProgress else { return }
                    self.pending = nil
                    self.debounceTask?.cancel()
                }
                .store(in: &cancellables)
        }

        override func viewSafeAreaInsetsDidChange() {
            super.viewSafeAreaInsetsDidChange()
            metrics.noteLayoutPass()
            // Rotation can update safe area without forcing a full layout pass.
            // If we only read in viewDidLayoutSubviews, we can miss the final post-rotation insets.
            captureAndScheduleUpdate()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            metrics.noteLayoutPass()
            captureAndScheduleUpdate()
        }

        private func captureAndScheduleUpdate() {
            let size = view.window?.bounds.size ?? view.bounds.size
            let insets = view.window?.safeAreaInsets ?? .zero
            let orientation = view.window?.windowScene?.interfaceOrientation ?? .unknown
            let snapshot = Snapshot(
                width: size.width,
                height: size.height,
                top: insets.top,
                left: insets.left,
                bottom: insets.bottom,
                right: insets.right,
                orientationRawValue: orientation.rawValue
            )

            // Always publish the first observation immediately.
            if lastSent == nil {
                lastSent = snapshot
                metrics.update(size: snapshot.size, insets: snapshot.insets, orientation: orientation)
                return
            }

            // If orientation changed, publish immediately and cancel any pending debounced update.
            // This prevents an old-orientation snapshot from being delivered later.
            if let lastSent, snapshot.orientationRawValue != lastSent.orientationRawValue {
                pending = nil
                debounceTask?.cancel()
                self.lastSent = snapshot
                metrics.update(size: snapshot.size, insets: snapshot.insets, orientation: orientation)
                return
            }

            // Cache the newest geometry and debounce commits to avoid rapid reflow during rotation/layout.
            pending = snapshot
            debounceTask?.cancel()
            // If nothing meaningfully changed since last update, do nothing.
            if let lastSent, snapshot.isApproximatelyEqual(to: lastSent, threshold: diffThreshold) {
                return
            }
            debounceTask = Task { @MainActor [weak self] in
                guard let self else { return }
                let nanos = UInt64((debounceSeconds * 1_000_000_000).rounded())
                try? await Task.sleep(nanoseconds: nanos)
                guard Task.isCancelled == false else { return }
                guard let pending = self.pending else { return }
                if let lastSent = self.lastSent, pending.isApproximatelyEqual(to: lastSent, threshold: self.diffThreshold) {
                    return
                }
                self.lastSent = pending
                self.metrics.update(
                    size: pending.size,
                    insets: pending.insets,
                    orientation: UIInterfaceOrientation(rawValue: pending.orientationRawValue) ?? .unknown
                )
            }
        }
        deinit {
            debounceTask?.cancel()
        }
    }
}
