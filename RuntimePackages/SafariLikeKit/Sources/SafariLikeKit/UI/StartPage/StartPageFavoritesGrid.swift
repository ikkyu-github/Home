import SwiftUI
import SafariLikeCoreKit
internal struct StartPageFavoritesGrid: View {
    let items: [BrowserBookmark]
    let onOpenURLString: (String) -> Void
    private let columns: [GridItem] = Array(
        repeating: GridItem(.fixed(72), spacing: 16, alignment: .top),
        count: 4
    )
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Favorites")
                .font(.headline)
                .foregroundStyle(.white)
            HStack {
                Spacer(minLength: 0)
                LazyVGrid(columns: columns, alignment: .center, spacing: 14) {
                    ForEach(items.prefix(8)) { item in
                        Button {
                            onOpenURLString(item.urlString)
                        } label: {
                            VStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 72, height: 72)
                                    .overlay {
                                        Image(systemName: "globe")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.85))
                                    }
                                Text(item.title)
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.92))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 72)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}
