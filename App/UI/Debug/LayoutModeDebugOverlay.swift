#if DEBUG
import SwiftUI

struct LayoutModeDebugOverlay: View {

    let debugName: String
    let width: CGFloat
    let height: CGFloat
    let horizontalSizeClass: UserInterfaceSizeClass?

    var body: some View {
        Text(
            "layoutMode: \(debugName)  w:\(Int(width))  h:\(Int(height))  hSize:\(String(describing: horizontalSizeClass))"
        )
        .font(.system(size: 12, weight: .bold))
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .padding()
        .allowsHitTesting(false)
    }
}
#endif
