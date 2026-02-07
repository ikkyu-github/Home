import Combine
import SwiftUI
import UIKit
import SafariLikeCoreKit
/// Scene-level metrics sourced from UIWindow/UIScene (not SwiftUI geometry).
///
/// Rationale: SwiftUI's GeometryReader safeAreaInsets/size can transiently report
/// incorrect values during rotation/resize, which can poison layout policy and
/// create persistent "ghost gaps". We debounce commits to stable values.
@MainActor
public final class SceneMetrics: ObservableObject {
    @Published public var containerSize: CGSize = .zero
    @Published public var safeAreaInsets: UIEdgeInsets = .zero
    @Published public var interfaceOrientation: UIInterfaceOrientation = .unknown

    @Published public private(set) var rotationInProgress: Bool = false
    /// Monotonic token incremented at every rotation/size transition start.
    /// Used to prevent cross-rotation reuse of debounced/stable metrics.
    @Published public private(set) var stableEpoch: UInt64 = 0
    // Stable values (debounced)
    @Published public private(set) var stableSize: CGSize = .zero
    @Published public private(set) var stableInsets: UIEdgeInsets = .zero
    @Published public private(set) var stableInterfaceOrientation: UIInterfaceOrientation = .unknown
    /// Epoch token associated with the current stable values.
    @Published public private(set) var stableCommittedEpoch: UInt64 = 0
    private var pendingStableSize: CGSize = .zero
    private var pendingStableInsets: UIEdgeInsets = .zero
    private var pendingStableOrientation: UIInterfaceOrientation = .unknown
    private var commitTask: Task<Void, Never>?
    private let diffThreshold: CGFloat = 1.0
    private let debounceNanoseconds: UInt64 = 140_000_000

    // Post-rotation settle sampling
    private var needsPostRotationSettle: Bool = false
    private var layoutPassesSinceRotationEnded: Int = 0
    private var lastGoodSamples: [Candidate] = []

    private struct Candidate {
        let size: CGSize
        let insets: UIEdgeInsets
        let orientation: UIInterfaceOrientation
        let epoch: UInt64
        func isApproximatelyEqual(to other: Candidate, threshold: CGFloat) -> Bool {
            abs(size.width - other.size.width) <= threshold
                && abs(size.height - other.size.height) <= threshold
                && abs(insets.top - other.insets.top) <= threshold
                && abs(insets.left - other.insets.left) <= threshold
                && abs(insets.bottom - other.insets.bottom) <= threshold
                && abs(insets.right - other.insets.right) <= threshold
                && orientation == other.orientation
                && epoch == other.epoch
        }
    }

    // Anti-poison bounds (tunable)
    private let maxReasonableInset: CGFloat = 120
    public init() {}

    public func rotationWillBegin() {
        stableEpoch &+= 1
        rotationInProgress = true
        // Critical: prevent any pending debounced stable commit from firing mid-rotation.
        commitTask?.cancel()
        pendingStableSize = .zero
        pendingStableInsets = .zero
        pendingStableOrientation = .unknown
        needsPostRotationSettle = false
        lastGoodSamples.removeAll(keepingCapacity: true)
        layoutPassesSinceRotationEnded = 0
    }

    public func rotationDidEnd() {
        rotationInProgress = false
        // Start settle sampling: require multiple layout passes + consecutive good samples.
        needsPostRotationSettle = true
        lastGoodSamples.removeAll(keepingCapacity: true)
        // Some UIKit transitions invoke the completion handler after the final layout pass,
        // so we may not receive additional viewDidLayoutSubviews callbacks. Seed the counter
        // to avoid permanently blocking stable commits in that scenario.
        layoutPassesSinceRotationEnded = 2

        // Also schedule a debounced commit using the latest observed scene snapshot.
        // This is resilient to cases where we only get a single post-rotation update.
        commitTask?.cancel()
        let scheduledEpoch = stableEpoch
        commitTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.debounceNanoseconds)
            guard !Task.isCancelled else { return }
            guard self.stableEpoch == scheduledEpoch else { return }
            guard self.rotationInProgress == false else { return }
            let size = self.containerSize
            let insets = self.safeAreaInsets
            let orientation = self.interfaceOrientation
            guard self.isSaneCandidate(size: size, insets: insets, orientation: orientation) else { return }
            self.stableSize = size
            self.stableInsets = insets
            self.stableInterfaceOrientation = orientation
            self.stableCommittedEpoch = scheduledEpoch
            self.needsPostRotationSettle = false
        }
    }

    public func noteLayoutPass() {
        guard rotationInProgress == false else { return }
        guard needsPostRotationSettle else { return }
        layoutPassesSinceRotationEnded += 1
    }

    public func update(size: CGSize, insets: UIEdgeInsets, orientation: UIInterfaceOrientation) {
        containerSize = size
        safeAreaInsets = insets
        interfaceOrientation = orientation

        // Do not commit stable metrics during rotation.
        guard rotationInProgress == false else { return }

        // Anti-poison: never commit stable values from an invalid snapshot.
        guard isSaneCandidate(size: size, insets: insets, orientation: orientation) else {
            return
        }

        let epoch = stableEpoch
        let candidate = Candidate(size: size, insets: insets, orientation: orientation, epoch: epoch)

        // After rotation ends, only commit stable once the layout has settled:
        // - wait for at least 2 layout passes
        // - require 2 consecutive sane samples that are approximately equal
        if needsPostRotationSettle {
            lastGoodSamples.append(candidate)
            if lastGoodSamples.count > 3 { lastGoodSamples.removeFirst(lastGoodSamples.count - 3) }

            // Fallback: if we don't get enough consecutive identical samples (or we only get
            // one post-rotation update), still commit stable metrics after a short debounce.
            // This prevents `stableCommittedEpoch` from getting stuck behind `stableEpoch`.
            if layoutPassesSinceRotationEnded >= 2 {
                pendingStableSize = candidate.size
                pendingStableInsets = candidate.insets
                pendingStableOrientation = candidate.orientation
                commitTask?.cancel()
                let scheduledEpoch = candidate.epoch
                commitTask = Task { @MainActor [weak self] in
                    guard let self else { return }
                    try? await Task.sleep(nanoseconds: self.debounceNanoseconds)
                    guard !Task.isCancelled else { return }
                    guard self.stableEpoch == scheduledEpoch else { return }
                    guard self.rotationInProgress == false else { return }
                    guard self.needsPostRotationSettle else { return }
                    self.stableSize = self.pendingStableSize
                    self.stableInsets = self.pendingStableInsets
                    self.stableInterfaceOrientation = self.pendingStableOrientation
                    self.stableCommittedEpoch = scheduledEpoch
                    self.needsPostRotationSettle = false
                }
            }

            if layoutPassesSinceRotationEnded >= 2,
               lastGoodSamples.count >= 2 {
                let a = lastGoodSamples[lastGoodSamples.count - 2]
                let b = lastGoodSamples[lastGoodSamples.count - 1]
                if b.isApproximatelyEqual(to: a, threshold: diffThreshold) {
                    stableSize = b.size
                    stableInsets = b.insets
                    stableInterfaceOrientation = b.orientation
                    stableCommittedEpoch = b.epoch
                    needsPostRotationSettle = false
                    commitTask?.cancel()
                }
            }
            return
        }

        let sizeChanged =
            abs(size.width - stableSize.width) > diffThreshold
            || abs(size.height - stableSize.height) > diffThreshold
        let insetsChanged =
            abs(insets.top - stableInsets.top) > diffThreshold
            || abs(insets.left - stableInsets.left) > diffThreshold
            || abs(insets.bottom - stableInsets.bottom) > diffThreshold
            || abs(insets.right - stableInsets.right) > diffThreshold
        guard sizeChanged || insetsChanged else { return }
        pendingStableSize = size
        pendingStableInsets = insets
        pendingStableOrientation = orientation
        // Debounce the "stable" commit to avoid flicker during rotation/resize.
        commitTask?.cancel()
        let scheduledEpoch = epoch
        commitTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.debounceNanoseconds)
            guard !Task.isCancelled else { return }
            // If a rotation/transition started since scheduling, do not commit.
            guard self.stableEpoch == scheduledEpoch else { return }
            guard self.rotationInProgress == false else { return }
            self.stableSize = self.pendingStableSize
            self.stableInsets = self.pendingStableInsets
            self.stableInterfaceOrientation = self.pendingStableOrientation
            self.stableCommittedEpoch = scheduledEpoch
        }
    }

    private func isSaneCandidate(size: CGSize, insets: UIEdgeInsets, orientation: UIInterfaceOrientation) -> Bool {
        guard size.width.isFinite, size.height.isFinite else { return false }
        guard size.width > 1, size.height > 1 else { return false }

        let edges = [insets.top, insets.left, insets.bottom, insets.right]
        guard edges.allSatisfy({ $0.isFinite }) else { return false }
        guard edges.allSatisfy({ $0 >= 0 && $0 <= maxReasonableInset }) else { return false }

        if (insets.top + insets.bottom) >= (size.height * 0.6) { return false }
        if (insets.left + insets.right) >= (size.width * 0.6) { return false }

        if let portraitLike = Self.isPortraitLike(orientation) {
            if portraitLike {
                if size.height + 1 < size.width { return false }
            } else {
                if size.width + 1 < size.height { return false }
            }
        }
        return true
    }

    private static func isPortraitLike(_ orientation: UIInterfaceOrientation) -> Bool? {
        switch orientation {
        case .portrait, .portraitUpsideDown:
            return true
        case .landscapeLeft, .landscapeRight:
            return false
        case .unknown:
            return nil
        @unknown default:
            return nil
        }
    }
}
