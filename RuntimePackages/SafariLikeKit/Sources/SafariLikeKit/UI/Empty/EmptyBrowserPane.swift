import SwiftUI
import SafariLikeUXKit
import SafariLikeCoreKit
struct EmptyBrowserPane: View {
    var onNewTab: (() -> Void)? = nil
    @Environment(\.uxPolicy) private var uxPolicy
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "globe")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No Active Tab")
                .font(.headline)
            Text("Open a new tab to start browsing")
                .font(.subheadline)
                .foregroundColor(.secondary)
            if let onNewTab = onNewTab {
                Button(action: onNewTab) {
                    Label(uxPolicy.strings.newTabTitle, systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding()
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
#Preview {
    EmptyBrowserPane(onNewTab: {})
}
