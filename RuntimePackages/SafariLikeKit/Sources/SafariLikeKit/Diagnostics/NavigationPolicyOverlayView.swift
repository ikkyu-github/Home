#if DEBUG
import SwiftUI
import SafariLikeCoreKit
@MainActor
public struct NavigationPolicyOverlayView: View {
    @EnvironmentObject private var context: SceneRuntimeContext
    private var model: NavigationPolicyOverlayModel { context.navigationPolicyOverlayModel }
    public init() {}
    public var body: some View {
        Group {
            if DiagnosticsGate.isEnabled, model.isVisible {
                overlayBody
            }
        }
    }
    private var overlayBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Policy")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                Spacer()
                Button("Hide") { model.toggle() }
                    .font(.system(.caption2, design: .monospaced))
            }
            Divider().opacity(0.4)
            row("tab", model.lastDecisionTabID)
            row("url", model.lastDecisionURL)
            row("decision", model.lastDecisionSummary)
        }
        .padding(10)
        .frame(maxWidth: 380)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12))
        )
        .padding(12)
    }
    private func row(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.system(.caption2, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
    }
}
public struct NavigationPolicyOverlayModifier: ViewModifier {
    public init() {}
    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .topLeading) {
                NavigationPolicyOverlayView()
            }
    }
}
public extension View {
    func navigationPolicyOverlay() -> some View {
        modifier(NavigationPolicyOverlayModifier())
    }
}
#endif
