import SwiftUI
import SafariLikeCoreKit
/// Safari-like rendering boundary.
///
/// Policy: Prefer `BrowserTab.State` for choosing surfaces, but allow a UI-level
/// override when the runtime has already produced a live WebView ("reality wins").
internal struct TabRenderer<Start: View, Web: View, Empty: View>: View {
    let tabState: BrowserTab.State?
    let preferWebContent: Bool
    @ViewBuilder let startPage: () -> Start
    @ViewBuilder let web: () -> Web
    @ViewBuilder let empty: () -> Empty
    var body: some View {
        Group {
            if preferWebContent {
                web()
            } else {
                switch tabState ?? .empty {
                case .startPage:
                    startPage()
                case .web:
                    web()
                case .empty:
                    empty()
                @unknown default:
                    empty()
                }
            }
        }
    }
}
