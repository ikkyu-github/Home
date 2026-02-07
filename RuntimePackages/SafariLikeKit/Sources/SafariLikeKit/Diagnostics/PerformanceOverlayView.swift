import SafariLikeCoreKit
#if DEBUG
import SwiftUI
import Combine
/// Debug-only overlay that surfaces recent performance milestones.
///
/// This file must not be compiled into Release builds.
@MainActor
public struct PerformanceOverlayView: View {
    @ObservedObject private var model: PerformanceOverlayModel
    public init(model: PerformanceOverlayModel) {
        self.model = model
    }
    public var body: some View {
        Group {
            if model.isVisible {
                overlayBody
                    .onAppear { model.start() }
                    .onDisappear { model.stop() }
            }
        }
    }
    private var overlayBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Performance")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                Spacer()
                Button("Hide") { model.toggle() }
                    .font(.system(.caption2, design: .monospaced))
            }
            Divider().opacity(0.4)
            metricSection(
                title: "Launch",
                rows: [
                    ("app.launch", model.lastAppLaunchDescription),
                    ("to first.ui", model.launchToFirstUIDescription),
                    ("to first.webview", model.launchToFirstWebViewDescription)
                ]
            )
            metricSection(
                title: "Tab Restore",
                rows: [
                    ("discarded→active", model.lastTabRestoreDescription)
                ]
            )
            metricSection(
                title: "Memory",
                rows: [
                    ("received", model.lastMemoryPressureDescription),
                    ("mitigation", model.memoryMitigationDescription)
                ]
            )
            metricSection(
                title: "Rendering",
                rows: [
                    ("live.webviews", model.liveWebViewsDescription),
                    ("render.state", model.renderStateSummaryDescription),
                    ("wv.create/reuse", model.webViewCreateReuseDescription),
                    ("wv.pool", model.webViewPoolSnapshotDescription),
                    ("attach→ready", model.attachToReadyDescription),
                    ("attach→paint", model.attachToFirstPaintDescription)
                ]
            )
        }
        .padding(10)
        .frame(maxWidth: 340)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12))
        )
        .padding(12)
    }
    private func metricSection(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .firstTextBaseline) {
                    Text(row.0)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 120, alignment: .leading)
                    Text(row.1)
                        .font(.system(.caption2, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
public struct PerformanceOverlayModifier: ViewModifier {
    @EnvironmentObject private var context: SceneRuntimeContext
    public init() {}
    public func body(content: Content) -> some View {
        let model = context.performanceOverlayModel
        content
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture(count: 3).onEnded {
                    model.toggle()
                }
            )
            .overlay(alignment: .topLeading) {
                PerformanceOverlayView(model: model)
            }
    }
}
public extension View {
    /// Adds the debug-only performance overlay.
    ///
    /// Toggle gesture: triple-tap anywhere.
    func performanceOverlay() -> some View {
        modifier(PerformanceOverlayModifier())
    }
}
#endif
