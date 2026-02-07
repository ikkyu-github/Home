import SafariLikeCoreKit
#if DEBUG
import SwiftUI
import CoreGraphics
internal struct DebugLayoutOverlay: View {
    let label: String
    let containerSize: CGSize
    let safeAreaInsets: EdgeInsets
    let sidebarWidth: CGFloat
    let relatedWidth: CGFloat
    let handleWidth: CGFloat
    var body: some View {
        GeometryReader { proxy in
            let global = proxy.frame(in: .global)
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .stroke(Color.red.opacity(0.95), lineWidth: 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("DEBUG LAYOUT: \(label)")
                        .fontWeight(.bold)
                    Text("global.origin: (x: \(fmt(global.origin.x)), y: \(fmt(global.origin.y)))")
                    Text("global.size: (w: \(fmt(global.size.width)), h: \(fmt(global.size.height)))")
                    Text("containerSize: (w: \(fmt(containerSize.width)), h: \(fmt(containerSize.height)))")
                    Text(
                        "safeAreaInsets: (t: \(fmt(safeAreaInsets.top)), l: \(fmt(safeAreaInsets.leading)), b: \(fmt(safeAreaInsets.bottom)), r: \(fmt(safeAreaInsets.trailing)))"
                    )
                    Text(
                        "widths: sidebar=\(fmt(sidebarWidth)) handle=\(fmt(handleWidth)) related=\(fmt(relatedWidth))"
                    )
                }
                .foregroundStyle(.primary)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(8)
            }
            .allowsHitTesting(false)
        }
    }
    private func fmt(_ value: CGFloat) -> String {
        String(format: "%.1f", value)
    }
}
#endif
