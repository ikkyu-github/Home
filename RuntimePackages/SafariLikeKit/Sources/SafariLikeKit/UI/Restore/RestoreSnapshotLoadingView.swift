import SwiftUI
import UIKit
import SafariLikeCoreKit
struct RestoreSnapshotLoadingView: View {
    let snapshotData: Data?
    let title: String
    init(snapshotData: Data?, title: String = "Restoring…") {
        self.snapshotData = snapshotData
        self.title = title
    }
    var body: some View {
        ZStack {
            snapshotBackground
            // Subtle dim + top progress bar. No full-screen spinner.
            LinearGradient(
                colors: [
                    Color.black.opacity(0.10),
                    Color.black.opacity(0.22)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            VStack(spacing: 10) {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(Color.white.opacity(0.65))
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(Color.white.opacity(0.75))
                    .padding(.horizontal, 14)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .accessibilityLabel(title)
        .allowsHitTesting(false)
    }
    @ViewBuilder
    private var snapshotBackground: some View {
        if let snapshotData, let image = UIImage(data: snapshotData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .blur(radius: 10)
                .saturation(0.9)
                .overlay(Color.black.opacity(0.08))
                .ignoresSafeArea()
        } else {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}
