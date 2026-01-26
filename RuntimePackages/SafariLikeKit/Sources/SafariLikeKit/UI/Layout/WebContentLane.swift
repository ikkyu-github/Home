import SwiftUI
import SafariLikeCoreKit

/// Dedicated lane for web content rendering.
/// - Must not contain Related/Sidebar/Overview logic.
/// - Width is provided by the container; this view must not impose width.
internal struct WebContentLane: View {
    @ObservedObject var vm: SplitBrowserViewModel
    let webContext: WebContext?
    let renderPolicy: RenderPolicyManager

    @State private var lastContextID: UUID?

    var body: some View {
        BrowserPaneView(viewModel: vm, webContext: webContext)
            .ignoresSafeArea(.all)
            .transaction { txn in
                // Never animate the WebView lane.
                txn.animation = nil
            }
            .onAppear {
                guard let webContext else { return }
                lastContextID = webContext.id
                renderPolicy.activate(webContext)
            }
            .onChange(of: webContext?.id) { newID in
                guard let webContext, let newID else { return }
                if let lastContextID, lastContextID != newID {
                    // Best-effort: mark prior context as non-active.
                    // (If it is still rendered elsewhere, that lane will re-activate it.)
                    // We intentionally do not try to resolve by ID here.
                }
                lastContextID = newID
                renderPolicy.activate(webContext)
            }
            .onDisappear {
                guard let webContext else { return }
                renderPolicy.deactivate(webContext)
            }
    }
}
