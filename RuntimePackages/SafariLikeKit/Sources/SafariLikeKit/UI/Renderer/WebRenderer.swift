import SwiftUI
import SafariLikeCoreKit
/// Renderer for `BrowserTab.State.web(...)`.
///
/// Note: WebView lifecycle (create/attach/evict) is owned by the runtime layer.
/// This view only renders whatever handle is currently attached.
internal struct WebRenderer: View {
    @ObservedObject var vm: SplitBrowserViewModel
    let webContext: WebContext?
    let renderPolicy: RenderPolicyManager
    var body: some View {
        WebContentLane(vm: vm, webContext: webContext, renderPolicy: renderPolicy)
    }
}

