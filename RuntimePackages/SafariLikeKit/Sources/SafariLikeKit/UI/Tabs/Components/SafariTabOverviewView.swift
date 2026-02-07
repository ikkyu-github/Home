import SwiftUI
import SafariLikeUXKit
import SafariLikeCoreKit
// BUILD-PERF-AUDIT(2026-01-21): Compile hotspot (SwiftUI grid/physics/layout tuning).
// Avoid growing this file’s dependency surface; keep helpers in dedicated, smaller files if needed.
internal struct SafariTabOverviewView: View {
    @EnvironmentObject private var chrome: BrowserChromeState
    @EnvironmentObject private var sceneMetrics: SceneMetrics
    @Environment(\.uxPolicy) private var uxPolicy
    let progress: CGFloat
    let tabs: [TabState]
    let tabGroups: [BrowserTabGroup]
    let selectedTabID: UUID?
    let selectedTabGroupID: UUID?
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onNewTab: () -> Void
    let onDone: (() -> Void)?
    let onScrollOffsetChanged: ((CGFloat) -> Void)?
    @GestureState private var isUserInteracting: Bool = false
    @State private var stableColumns: Int = 1
    private var policy: OverviewLayoutPolicy { uxPolicy.tabOverview.layout }
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let stable = sceneMetrics.stableInsets
            let safe: EdgeInsets = (stable != .zero)
                ? EdgeInsets(top: stable.top, leading: stable.left, bottom: stable.bottom, trailing: stable.right)
                : proxy.safeAreaInsets
            let safeWidth = max(0, size.width - safe.leading - safe.trailing)
            let nextCols = policy.columns(containerWidth: safeWidth, previous: stableColumns)
            let spacing = policy.resolvedInterCardSpacing(containerWidth: safeWidth)
            let cardSize = policy.cardSize(containerWidth: safeWidth, columns: nextCols, interCardSpacing: spacing)
            let sectionInsets = EdgeInsets(
                top: policy.sectionInsets.top,
                leading: policy.sectionInsets.leading,
                bottom: policy.sectionInsets.bottom,
                trailing: policy.sectionInsets.trailing
            )
            let scale = policy.scaleCurve.scale(progress: progress)
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    SafariTabOverviewHeader(containerSize: size, safeTop: safe.top)
                    SafariTabAdaptiveGrid(
                        tabs: tabs,
                        selectedTabID: selectedTabID,
                        selectedTabGroupID: selectedTabGroupID,
                        columns: nextCols,
                        cardSize: cardSize,
                        sectionInsets: sectionInsets,
                        interCardSpacing: spacing,
                        onSelect: onSelect,
                        onClose: onClose,
                        onScrollOffsetChanged: onScrollOffsetChanged
                    )
                    .scaleEffect(scale)
                }
                SafariTabOverviewBottomBar(
                    tabCount: tabs.count,
                    onNewTab: onNewTab,
                    onDone: onDone
                )
                .padding(.horizontal, 16)
                .padding(.bottom, max(12, safe.bottom == 0 ? 18 : safe.bottom))
            }
            .onAppear {
                stableColumns = policy.columns(containerWidth: safeWidth, previous: nil)
            }
            .onChange(of: safeWidth) { newWidth in
                stableColumns = policy.columns(containerWidth: newWidth, previous: stableColumns)
            }
            .onChange(of: isUserInteracting) { isInteracting in
                chrome.setTabOverviewUserInteracting(isInteracting)
            }
            .onDisappear {
                chrome.setTabOverviewUserInteracting(false)
            }
            .simultaneousGesture(overviewInteractionGesture)
        }
    }
    private var overviewInteractionGesture: some Gesture {
        DragGesture(minimumDistance: uxPolicy.gestures.tabOverviewInteractionMinimumDistance)
            .updating($isUserInteracting) { _, state, _ in
                state = true
            }
    }
}
internal struct SafariTabOverviewHeader: View {
    let containerSize: CGSize
    let safeTop: CGFloat
    var body: some View {
        let isLandscape = containerSize.width > containerSize.height
        HStack {
            Text("Tabs")
                .font(.system(size: isLandscape ? 22 : 28, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, (isLandscape ? 10 : 14) + safeTop)
        .padding(.bottom, isLandscape ? 6 : 10)
    }
}
internal struct SafariTabOverviewBottomBar: View {
    let tabCount: Int
    let onNewTab: () -> Void
    let onDone: (() -> Void)?
    var body: some View {
        HStack(spacing: 14) {
            Button(action: onNewTab) {
                Image(systemName: "plus")
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
            Spacer()
            Text("\(tabCount) แถบ")
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.white.opacity(0.14)))
            Spacer()
        }
        .padding(10)
        .background(Capsule().fill(Color.black.opacity(0.18)))
    }
}
