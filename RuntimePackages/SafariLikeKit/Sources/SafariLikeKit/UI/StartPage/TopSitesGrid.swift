import SwiftUI
import SafariLikeCoreKit
internal struct TopSitesGrid: View {
    let items: [BrowserBookmark]
    let onOpenURLString: (String) -> Void
    @State private var measuredWidth: CGFloat = 0
    private let itemSize: CGFloat = 72
    private let minSpacing: CGFloat = 8
    private let maxSpacing: CGFloat = 24
    var body: some View {
        let layout = gridLayout(containerWidth: measuredWidth)
        VStack(alignment: .leading, spacing: 10) {
            Text("Favorites")
                .font(.headline)
                .foregroundStyle(.white)
            LazyVGrid(columns: layout.columns, alignment: .center, spacing: layout.spacing) {
                ForEach(items.prefix(8)) { item in
                    Button {
                        onOpenURLString(item.urlString)
                    } label: {
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .frame(width: itemSize, height: itemSize)
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
                                .frame(width: itemSize)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, layout.outerPadding)
            .frame(maxWidth: .infinity)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: TopSitesGridWidthPreferenceKey.self, value: geo.size.width)
                }
            )
            .onPreferenceChange(TopSitesGridWidthPreferenceKey.self) { measuredWidth = $0 }
        }
        .frame(maxWidth: .infinity)
    }
    private func gridLayout(containerWidth: CGFloat) -> (columns: [GridItem], spacing: CGFloat, outerPadding: CGFloat) {
        let width = max(0, containerWidth)
        let maxItems = max(1, min(items.count, 8))
        guard width > 0 else {
            let defaultCols = min(4, maxItems)
            let columns = Array(
                repeating: GridItem(.fixed(itemSize), spacing: 14, alignment: .top),
                count: defaultCols
            )
            return (columns, 14, 0)
        }
        // Pick a column count based on the real container width.
        // We aim for at least `minSpacing` between items.
        let proposed = Int((width + minSpacing) / (itemSize + minSpacing))
        let cols = min(maxItems, max(1, proposed))
        let rawSpacing: CGFloat = (cols <= 1)
            ? 0
            : (width - (CGFloat(cols) * itemSize)) / CGFloat(cols - 1)
        let spacing = max(minSpacing, min(maxSpacing, rawSpacing))
        let total = (CGFloat(cols) * itemSize) + (CGFloat(max(0, cols - 1)) * spacing)
        let outerPadding = max(0, (width - total) / 2)
        let columns = Array(
            repeating: GridItem(.fixed(itemSize), spacing: spacing, alignment: .top),
            count: cols
        )
        return (columns, spacing, outerPadding)
    }
}
private struct TopSitesGridWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
