import SwiftUI
import SafariLikeCoreKit
struct SidebarView: View {
    // MARK: - Item
    enum Item: Hashable {
        case startPage
        case privateMode
        case newTab
        case tabOverview
        case bookmarks
        case readingList
        case history
        case settings
    }
    // MARK: - Callback
    let onSelect: (Item) -> Void
    // MARK: - Body
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                sidebarButton(
                    icon: "house",
                    title: "หน้าที่เริ่มต้น",
                    item: .startPage
                )
                sidebarButton(
                    icon: "hand.raised",
                    title: "ส่วนตัว",
                    item: .privateMode
                )
                sidebarButton(
                    icon: "plus.square.on.square",
                    title: "แท็บใหม่",
                    item: .newTab
                )
                sidebarButton(
                    icon: "square.grid.2x2",
                    title: "ภาพรวมแท็บ",
                    item: .tabOverview
                )
                Divider().opacity(0.4)
                sidebarButton(
                    icon: "book",
                    title: "บุ๊กมาร์ค",
                    item: .bookmarks
                )
                sidebarButton(
                    icon: "eyeglasses",
                    title: "รายการอ่าน",
                    item: .readingList
                )
                sidebarButton(
                    icon: "clock",
                    title: "ประวัติ",
                    item: .history
                )
                Divider().opacity(0.4)
                sidebarButton(
                    icon: "gearshape",
                    title: "ตั้งค่า",
                    item: .settings
                )
            }
            .padding(.top, 20)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .ignoresSafeArea(.container, edges: [.horizontal])
        .background(.ultraThinMaterial)
    }
    // MARK: - Button
    @ViewBuilder
    private func sidebarButton(
        icon: String,
        title: String,
        item: Item
    ) -> some View {
        Button {
            onSelect(item)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(.primary)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
