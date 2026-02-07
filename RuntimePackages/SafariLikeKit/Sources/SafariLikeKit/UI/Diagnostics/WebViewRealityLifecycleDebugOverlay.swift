#if DEBUG
import SwiftUI
import SafariLikeCoreKit
/// Safari-style, read-only overlay for spotting desync between lifecycle state and UIKit/WebKit reality.
///
/// Rules:
/// - Debug-only
/// - Read-only (no buttons, no mutations)
/// - Must not add observers
internal struct WebViewRealityLifecycleDebugOverlay: View {
    let tabID: UUID?
    let attachmentState: WebViewAttachmentState
    let attachmentUpdatedAt: Date
    let isRealityReady: Bool
    let hasWindow: Bool
    let hasSuperview: Bool
    let frame: CGRect
    let lastReconcileAt: Date?
    private var tabPrefix: String {
        guard let tabID else { return "nil" }
        return String(tabID.uuidString.prefix(8))
    }
    private var frameString: String {
        String(format: "x=%.0f y=%.0f w=%.0f h=%.0f", frame.origin.x, frame.origin.y, frame.size.width, frame.size.height)
    }
    private func formatTime(_ date: Date?) -> String {
        guard let date else { return "nil" }
        return date.formatted(date: .omitted, time: .standard)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("REALITY ↔︎ LIFECYCLE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
            Text(verbatim: "tab=\(tabPrefix)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
            Text(verbatim: "attach=\(String(describing: attachmentState)) @ \(formatTime(attachmentUpdatedAt))")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
            Text(verbatim: "reality ready=\(isRealityReady) window=\(hasWindow) super=\(hasSuperview)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
            Text(verbatim: "frame=\(frameString)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
            Text(verbatim: "last reconcile=\(formatTime(lastReconcileAt))")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .padding(8)
        .background(Color.black.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(radius: 8)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
#endif
