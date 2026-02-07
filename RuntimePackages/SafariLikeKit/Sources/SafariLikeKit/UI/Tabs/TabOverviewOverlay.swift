import SwiftUI
import SafariLikeUXKit
import SafariLikeCoreKit
/// Tab overview overlay (scrim + grid).
internal struct TabOverviewOverlay: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var tabOverviewTransition: TabOverviewTransitionController
    @EnvironmentObject private var chrome: BrowserChromeState
    @Environment(\.uxPolicy) private var uxPolicy
    @Binding var isVisible: Bool
    /// 0...1 presentation progress (driven by root). Also used for interactive dismiss.
    let progress: CGFloat
    /// Let root know when we're actively dragging (so it doesn't fight our progress).
    let isDragging: Bool
    let tabs: [TabState]
    let tabGroups: [BrowserTabGroup]
    let selectedTabID: UUID?
    let selectedTabGroupID: UUID?
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onNewTab: () -> Void
    private func dismiss() {
        // Drive a single, interruptible dismissal path.
        tabOverviewTransition.requestDismiss()
    }
    var body: some View {
        // Critical: SwiftUI still hit-tests views with near-zero opacity.
        // To avoid invisible "tap blockers" during transitions, only enable hit testing
        // once the overlay is visibly presented.
        let isInteractionEnabled = progress > 0.1
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            // Scrim intensity follows progress (Safari-like). Also used as a tap-to-dismiss.
            Color.black
                .opacity(0.18 * Double(max(0, min(1, progress))))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .allowsHitTesting(progress > 0.1) // ✅ Only allow hit testing when overlay is visible enough
                .onTapGesture {
                    dismiss()
                }
            if horizontalSizeClass == .compact {
                // iPhone: grid-only (Safari-like), no vertical list mode.
                TabOverviewGridView(
                    progress: progress,
                    tabs: tabs,
                    tabGroups: tabGroups,
                    selectedTabID: selectedTabID,
                    selectedTabGroupID: selectedTabGroupID,
                    onSelect: { id in
                        onSelect(id)
                        dismiss()
                    },
                    onClose: onClose,
                    onNewTab: onNewTab,
                    onDone: {
                        dismiss()
                    }
                )
            } else {
                TabOverviewView(
                    overviewProgress: progress,
                    tabs: tabs,
                    selectedTabID: Binding(
                        get: { selectedTabID },
                        set: { newValue in
                            guard let id = newValue else { return }
                            onSelect(id)
                            dismiss()
                        }
                    ),
                    onClose: onClose,
                    onNewTab: onNewTab,
                    onDismissOverview: {
                        dismiss()
                    }
                )
            }
        }
        .allowsHitTesting(isInteractionEnabled)
        // The overlay itself fades in/out subtly, but the main "feel" comes from root transform.
        .opacity(Double(max(0.0, min(1.0, progress))))
        .onAppear {
            // Centralize overview thumbnail capture requests so we don't duplicate pipelines
            // across multiple overview implementations.
            if isVisible {
                chrome.requestOverviewThumbnailsCapture()
            }
        }
        .onChange(of: isVisible) { newValue in
            if newValue {
                chrome.requestOverviewThumbnailsCapture()
            }
        }
    }
}
