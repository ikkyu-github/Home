import SwiftUI
import BrowserCore
import SafariLikeUXKit

/// Simple tab overview grid (Safari-like) with adaptive cards.
///
/// Notes:
/// - Uses `LazyVGrid(.adaptive)`.
/// - Shows a thumbnail when available via `BrowserChromeState.thumbnails`, otherwise a placeholder.
/// - Selection is driven by `selectedTabID` binding.

internal struct TabOverviewView: View {
    @EnvironmentObject private var chrome: BrowserChromeState
    @EnvironmentObject private var sceneMetrics: SceneMetrics

    @State private var isListMode: Bool = false
    @GestureState private var isUserInteracting: Bool = false
    @State private var stableColumns: Int = 2

    let tabs: [TabState]
    @Binding var selectedTabID: UUID?
    let onClose: (UUID) -> Void
    let onNewTab: () -> Void

    /// 0...1 presentation progress (used for scale tuning).
    let overviewProgress: CGFloat

    /// Optional hook for parents that can dismiss the overview container.
    let onDismissOverview: (() -> Void)?

    /// Optional hook for parents that need side-effects (e.g. dismiss overlay).
    let onSelect: ((UUID) -> Void)?

    init(
        overviewProgress: CGFloat,
        tabs: [TabState],
        selectedTabID: Binding<UUID?>,
        onClose: @escaping (UUID) -> Void,
        onNewTab: @escaping () -> Void,
        onDismissOverview: (() -> Void)? = nil,
        onSelect: ((UUID) -> Void)? = nil
    ) {
        self.overviewProgress = overviewProgress
        self.tabs = tabs
        self._selectedTabID = selectedTabID
        self.onClose = onClose
        self.onNewTab = onNewTab
        self.onDismissOverview = onDismissOverview
        self.onSelect = onSelect
    }

    private let policy: OverviewLayoutPolicy = .default

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let stable = sceneMetrics.stableInsets
            let safe: EdgeInsets = (stable != .zero)
                ? EdgeInsets(top: stable.top, leading: stable.left, bottom: stable.bottom, trailing: stable.right)
                : proxy.safeAreaInsets
            let safeWidth = max(0, size.width - safe.leading - safe.trailing)

            let nextCols = policy.columns(containerWidth: safeWidth, previous: stableColumns)
            let cardSize = policy.cardSize(containerWidth: safeWidth, columns: nextCols)
            let sectionInsets = EdgeInsets(
                top: policy.sectionInsets.top,
                leading: policy.sectionInsets.leading,
                bottom: policy.sectionInsets.bottom,
                trailing: policy.sectionInsets.trailing
            )
            let scale = policy.scaleCurve.scale(progress: overviewProgress)

            VStack(spacing: 0) {
                header(safeTop: safe.top)

                if isListMode {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(tabs) { tab in
                                TabListRow(
                                    tab: tab,
                                    isSelected: tab.id == selectedTabID,
                                    onSelect: {
                                        selectedTabID = tab.id
                                        onSelect?(tab.id)
                                        onDismissOverview?()
                                    },
                                    onClose: {
                                        onClose(tab.id)
                                    }
                                )
                            }
                        }
                        .padding(sectionInsets)
                    }
                    .simultaneousGesture(overviewInteractionGesture)
                } else {
                    let gridItems = Array(repeating: GridItem(.fixed(cardSize.width), spacing: policy.interCardSpacing, alignment: .top), count: max(1, nextCols))

                    ScrollView {
                        LazyVGrid(columns: gridItems, spacing: policy.interCardSpacing) {
                            ForEach(tabs) { tab in
                                TabCard(
                                    tab: tab,
                                    isSelected: tab.id == selectedTabID,
                                    thumbnail: chrome.thumbnails.thumbnail(for: tab.id),
                                    cardSize: cardSize,
                                    onSelect: {
                                        selectedTabID = tab.id
                                        onSelect?(tab.id)
                                    },
                                    onClose: {
                                        onClose(tab.id)
                                    },
                                    onDismissOverview: {
                                        onDismissOverview?()
                                    }
                                )
                            }
                        }
                        .padding(sectionInsets)
                    }
                    .simultaneousGesture(overviewInteractionGesture)
                }
            }
            .scaleEffect(scale)
            .onAppear {
                stableColumns = policy.columns(containerWidth: safeWidth, previous: nil)
            }
            .onChange(of: safeWidth) { newWidth in
                stableColumns = policy.columns(containerWidth: newWidth, previous: stableColumns)
            }
        }
        .onAppear {
            chrome.requestOverviewThumbnailsCapture()
        }
        .onChange(of: isUserInteracting) { isInteracting in
            chrome.setTabOverviewUserInteracting(isInteracting)
        }
        .onDisappear {
            chrome.setTabOverviewUserInteracting(false)
        }
    }

    private var overviewInteractionGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .updating($isUserInteracting) { _, state, _ in
                state = true
            }
    }

    private func header(safeTop: CGFloat) -> some View {
        HStack(spacing: 12) {
            Text("Tabs")
                .font(.system(size: 22, weight: .semibold))

            Spacer()

            Button {
                isListMode.toggle()
            } label: {
                Image(systemName: isListMode ? "square.grid.2x2" : "list.bullet")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isListMode ? "Grid" : "List")

            Button(action: onNewTab) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New Tab")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16 + safeTop)
        .padding(.bottom, 8)
    }
}

private struct TabCard: View {
    let tab: TabState
    let isSelected: Bool
    let thumbnail: UIImage?
    let cardSize: CGSize
    let onSelect: () -> Void
    let onClose: () -> Void
    let onDismissOverview: () -> Void

    private var displayTitle: String {
        let trimmed = tab.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false ? (trimmed ?? "") : "New Tab")
    }

    private var displayURL: String {
        tab.url?.absoluteString ?? ""
    }

    @GestureState private var dragTranslation: CGSize = .zero
    @State private var committedOffset: CGSize = .zero

    private enum PendingAction: Equatable {
        case close(target: CGSize)
        case dismiss(target: CGSize)
    }

    @State private var pendingAction: PendingAction?

    private let physics = SafariPhysicsConfig.default

    var body: some View {
        let previewHeight = max(110, cardSize.height - 96)

        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                ZStack {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.10),
                                        Color.white.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .allowsHitTesting(false)

                        Image(systemName: "globe")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .frame(height: previewHeight)
                .clipped()

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if displayURL.isEmpty == false {
                        Text(displayURL)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.black.opacity(0.12))
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.70) : Color.white.opacity(0.10), lineWidth: isSelected ? 2 : 1)
                    .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .frame(width: cardSize.width)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture(perform: onSelect)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .allowsHitTesting(false)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            .allowsHitTesting(false)
                    )
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel("Close Tab")
        }
        .offset(x: committedOffset.width + dragTranslation.width, y: committedOffset.height + dragTranslation.height)
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.88), value: dragTranslation)
        .animation(.spring(response: 0.30, dampingFraction: 0.90), value: committedOffset)
        .onAnimationCompleted(for: committedOffset) {
            guard let pendingAction else { return }
            switch pendingAction {
            case .close(let target) where committedOffset == target:
                self.pendingAction = nil
                onClose()
            case .dismiss(let target) where committedOffset == target:
                self.pendingAction = nil
                onDismissOverview()
            default:
                break
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 6)
                .updating($dragTranslation) { value, state, _ in
                    // Follow the finger, but keep it feeling intentional.
                    let dx = value.translation.width
                    let dy = value.translation.height

                    if TabCardSwipePolicy.dominantAxis(dx: dx, dy: dy) == .horizontal {
                        // Horizontal swipe (close)
                        state = CGSize(
                            width: max(-physics.tabOverviewCard.maxDragX, min(physics.tabOverviewCard.maxDragX, dx)),
                            height: 0
                        )
                    } else {
                        // Vertical swipe (dismiss) — only allow downward drag
                        state = CGSize(
                            width: 0,
                            height: max(0, min(physics.tabOverviewCard.maxDragY, dy))
                        )
                    }
                }
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height

                    let outcome = TabCardSwipePolicy.decideEnd(
                        dx: dx,
                        dy: dy,
                        config: .init(
                            closeThresholdX: physics.tabOverviewCard.closeThresholdX,
                            dismissThresholdY: physics.tabOverviewCard.dismissThresholdY
                        )
                    )

                    switch outcome {
                    case .close(let direction):
                        let target = CGSize(width: direction * 600, height: 0)
                        pendingAction = .close(target: target)
                        withAnimation(.spring(response: physics.overviewSpring.response, dampingFraction: physics.overviewSpring.dampingFraction)) {
                            committedOffset = target
                        }
                        return
                    case .dismiss:
                        let target = CGSize(width: 0, height: 320)
                        pendingAction = .dismiss(target: target)
                        withAnimation(.spring(response: physics.overviewSpring.response, dampingFraction: physics.overviewSpring.dampingFraction)) {
                            committedOffset = target
                        }
                        return
                    case .reset:
                        break

                    @unknown default:
                        break
                    }

                    pendingAction = nil
                    withAnimation(.spring(response: physics.overviewSpring.response, dampingFraction: physics.overviewSpring.dampingFraction)) {
                        committedOffset = .zero
                    }
                }
        )
    }
}

private struct TabListRow: View {
    let tab: TabState
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    private var displayTitle: String {
        let trimmed = tab.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false ? (trimmed ?? "") : "New Tab")
    }

    private var displayURL: String {
        tab.url?.absoluteString ?? ""
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)

                    if displayURL.isEmpty == false {
                        Text(displayURL)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .padding(.trailing, 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.7) : Color.clear, lineWidth: 2)
                    .allowsHitTesting(false)
            )
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    onSelect()
                }
            )

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
        }
    }
}
