import SwiftUI
import SafariLikeCoreKit
internal struct SidebarLibraryContainer<Content: View>: View {
    let title: String
    let systemImage: String
    let isOverlay: Bool
    let onBack: () -> Void
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { onBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .padding(.bottom, 10)
            Divider().opacity(0.4)
            content()
        }
    }
}
