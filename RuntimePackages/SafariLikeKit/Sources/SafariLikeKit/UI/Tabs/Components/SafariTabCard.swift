import SwiftUI
import UIKit
import SafariLikeUXKit
import SafariLikeCoreKit
internal struct SafariTabCard: View {
    let tab: TabState
    let isSelected: Bool
    let previewHeight: CGFloat
    let cardWidth: CGFloat?
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    @State private var snapshotImage: UIImage?
    @State private var snapshotVisible: Bool = false
    @Environment(\.uxPolicy) private var uxPolicy
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                onSelect(tab.id)
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    let fallback = uxPolicy.strings.newTabTitle
                    Text((tab.title ?? "").isEmpty ? fallback : (tab.title ?? fallback))
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.10))
                        .frame(height: previewHeight)
                        .overlay {
                            ZStack {
                                // Placeholder (always present behind snapshot)
                                LinearGradient(
                                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                Image(systemName: "safari")
                                    .font(.system(size: 40))
                                    .opacity(0.22)
                                if let snapshotImage {
                                    Image(uiImage: snapshotImage)
                                        .resizable()
                                        .scaledToFill()
                                        .clipped()
                                        .opacity(snapshotVisible ? 1 : 0)
                                        .scaleEffect(snapshotVisible ? 1 : 0.985)
                                        .animation(.easeOut(duration: 0.22), value: snapshotVisible)
                                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(14)
                .frame(width: cardWidth)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.white.opacity(isSelected ? 0.16 : 0.10))
                )
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .safariHoverHighlight(cornerRadius: 22, opacity: 0.05)
            }
            .buttonStyle(SafariPressableScaleButtonStyle(baseScale: isSelected ? 0.95 : 0.92))
            .zIndex(isSelected ? 1 : 0)
            .contextMenu {
                // Privacy: never offer cross-window actions for private tabs.
                if tab.isPrivate == false, let url = tab.url {
                    Button("Open in New Window") {
                        AppWindowActions.openURL(url, inNewWindow: true)
                    }
                    Button("Move to New Window") {
                        AppWindowActions.openURL(url, inNewWindow: true)
                        onClose(tab.id)
                    }
                }
            }
            Button { onClose(tab.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.black.opacity(0.50)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            .padding(.trailing, 10)
        }
        .task(id: tab.snapshotData) {
            await loadSnapshotImage()
        }
    }
    private func loadSnapshotImage() async {
        snapshotVisible = false
        guard let data = tab.snapshotData, !data.isEmpty else {
            snapshotImage = nil
            return
        }
        // Decode off-main to keep scrolling smooth.
        let decoded: UIImage? = await Task.detached(priority: .utility) {
            UIImage(data: data)
        }.value
        snapshotImage = decoded
        if decoded != nil {
            withAnimation(.easeOut(duration: 0.22)) {
                snapshotVisible = true
            }
        }
    }
}
