import SwiftUI
import SafariLikeCoreKit
internal struct StartPageReadingListView: View {
    let items: [BrowserReadingListItem]
    let onOpenItem: (BrowserReadingListItem) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reading List")
                .font(.headline)
                .foregroundStyle(.white)
            VStack(spacing: 10) {
                ForEach(items.prefix(4)) { item in
                    Button {
                        onOpenItem(item)
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Image(systemName: item.isRead ? "book" : "book.closed")
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                Text(item.urlString)
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.black.opacity(0.18))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
