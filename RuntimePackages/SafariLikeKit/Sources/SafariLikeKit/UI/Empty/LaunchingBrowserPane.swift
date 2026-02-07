import SwiftUI
import SafariLikeCoreKit
struct LaunchingBrowserPane: View {
    let title: String
    let subtitle: String
    init(
        title: String = "Launching…",
        subtitle: String = "Preparing your tab"
    ) {
        self.title = title
        self.subtitle = subtitle
    }
    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView()
                .scaleEffect(1.1)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
