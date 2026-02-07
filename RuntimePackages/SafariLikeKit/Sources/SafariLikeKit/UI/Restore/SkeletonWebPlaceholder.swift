import SwiftUI
import SafariLikeCoreKit
struct SkeletonWebPlaceholder: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.14))
                    .frame(width: 220, height: 14)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.10))
                    .frame(width: 180, height: 14)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: 260, height: 14)
            }
            .padding(20)
        }
        .allowsHitTesting(false)
        .accessibilityLabel("Loading")
    }
}
