import SwiftUI
import SafariLikeUXKit
import SafariLikeCoreKit
struct TabStripView: View {
    let title: String
    let isSelected: Bool
    let onClose: () -> Void
    @Environment(\.uxPolicy) private var uxPolicy
    var body: some View {
        HStack(spacing: 8) {
            Text(title.isEmpty ? uxPolicy.strings.newTabTitle : title)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(isSelected ? .primary : .secondary)
            Spacer(minLength: 8)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel("Close Tab")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.16) : Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(isSelected ? 0.22 : 0.10), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(isSelected ? 0.22 : 0.10), radius: isSelected ? 10 : 6, y: 3)
        .animation(.spring(response: 0.26, dampingFraction: 0.9), value: isSelected)
    }
}
#if DEBUG
struct TabStripView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            TabStripView(title: "OpenAI", isSelected: true, onClose: {})
            TabStripView(title: "", isSelected: false, onClose: {})
        }
        .padding()
        .previewLayout(.sizeThatFits)
        .background(Color(.systemBackground))
    }
}
#endif
