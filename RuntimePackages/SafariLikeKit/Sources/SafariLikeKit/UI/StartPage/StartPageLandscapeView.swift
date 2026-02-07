import SwiftUI
import CoreGraphics
import SafariLikeCoreKit
internal struct StartPageLandscapeView: View {
    @EnvironmentObject private var chrome: BrowserChromeState
    @ObservedObject var bookmarkStore: BookmarkStore
    let leadingSafePadding: CGFloat
    let trailingSafePadding: CGFloat
    let onOpenURLString: (String) -> Void
    private var favorites: [BrowserBookmark] {
        Array(bookmarkStore.items.prefix(6))
    }
    private let favoriteColumns: [GridItem] = Array(
        repeating: GridItem(.fixed(84), spacing: 18, alignment: .top),
        count: 3
    )
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("หน้าที่เริ่มต้น")
                        .font(.system(size: 28, weight: .bold))
                        .padding(.top, 8)
                    introCard
                    if !favorites.isEmpty {
                        favoritesSection
                    }
                    privacyReportCard
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, leadingSafePadding)
                .padding(.trailing, trailingSafePadding)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
extension StartPageLandscapeView {
    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ยินดีต้อนรับสู่ SafariPad")
                .font(.headline)
            Text("คุณสามารถกำหนดหน้าที่เริ่มต้นเอง และเข้าถึงรายการโปรดได้อย่างรวดเร็ว")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                chrome.isAppSettingsPresented = true
            } label: {
                Text("กำหนดหน้าที่เริ่มต้นเอง")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("รายการโปรด")
                .font(.headline)
            LazyVGrid(columns: favoriteColumns, alignment: .leading, spacing: 16) {
                ForEach(favorites) { item in
                    Button {
                        onOpenURLString(item.urlString)
                    } label: {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(Color(.secondarySystemGroupedBackground))
                                .frame(width: 72, height: 72)
                                .overlay {
                                    Image(systemName: "globe")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }
                            Text(item.title.isEmpty ? item.urlString : item.title)
                                .font(.footnote)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(width: 84)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private var privacyReportCard: some View {
        Button {
            chrome.isPrivacyReportPresented = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                    Image(systemName: "shield.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.green)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text("รายงานความเป็นส่วนตัว")
                        .font(.headline)
                    Text("ดูภาพรวมการป้องกันการติดตาม และการตั้งค่าความเป็นส่วนตัว")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
