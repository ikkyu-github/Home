import SwiftUI
import UIKit

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

    // Stable values (debounced)
    @Published public private(set) var stableSize: CGSize = .zero
    @Published public private(set) var stableInsets: UIEdgeInsets = .zero

    private var pendingStableSize: CGSize = .zero
    private var pendingStableInsets: UIEdgeInsets = .zero
    private var commitTask: Task<Void, Never>?

    private let diffThreshold: CGFloat = 0.5
    private let debounceNanoseconds: UInt64 = 140_000_000

    public init() {}

    public func update(size: CGSize, insets: UIEdgeInsets, orientation: UIInterfaceOrientation) {
        containerSize = size
        safeAreaInsets = insets
        interfaceOrientation = orientation

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

        // Debounce the "stable" commit to avoid flicker during rotation/resize.
        commitTask?.cancel()
        commitTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.debounceNanoseconds)
            guard !Task.isCancelled else { return }
            self.stableSize = self.pendingStableSize
            self.stableInsets = self.pendingStableInsets
        }
    }
}
