import SwiftUI
import SafariLikeUXKit
import SafariLikeCoreKit
struct CompactTabPill: View {
    let title: String
    let urlString: String
    let isSelected: Bool
    let width: CGFloat
    let showClose: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var isHovered: Bool = false
    @Environment(\.uxPolicy) private var uxPolicy
    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: onSelect) {
                HStack(spacing: 6) {
                    Text(title.isEmpty ? uxPolicy.strings.newTabTitle : title)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if showClose {
                        // Reserve space so title doesn't jump when close is visible.
                        Color.clear
                            .frame(width: 18, height: 18)
                    }
                }
                .padding(.horizontal, 10)
                .frame(width: width, height: 28)
                .background(
                    Capsule()
                        .fill(isSelected
                              ? Color.white.opacity(0.18)
                              : Color.white.opacity(0.10))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(isSelected ? 0.25 : 0.12), lineWidth: 1)
                )
                .overlay(
                    Capsule()
                        .fill(Color.white.opacity(isHovered ? 0.05 : 0))
                        .allowsHitTesting(false)
                )
                .contentShape(Capsule())
            }
            .buttonStyle(SafariPressableScaleButtonStyle())
            .onHover { hovering in
                withAnimation(.linear(duration: 0.12)) { isHovered = hovering }
            }
            .hoverEffect(.highlight)
            if showClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.semibold))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 6)
                .accessibilityLabel("Close Tab")
            }
        }
    }
}
