import SwiftUI
import SafariLikeCoreKit
internal struct LibrarySheetScaffold<Content: View, Empty: View, Toolbar: View>: View {
    let title: String
    let content: () -> Content
    let emptyState: () -> Empty
    let toolbar: () -> Toolbar
    let isEmpty: Bool
    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.title2)
                .bold()
                .padding(.top, 16)
            Divider()
            if isEmpty {
                emptyState()
            } else {
                content()
            }
            Spacer()
            Divider()
            toolbar()
                .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding()
    }
}
