import SwiftUI
import SafariLikeKit

struct PerformanceSettingsView: View {

    @ObservedObject var settings: AppSettings
    @EnvironmentObject private var sceneContext: SceneRuntimeContext

    var body: some View {
        PerformanceSettingsViewContent(
            settings: settings,
            perf: sceneContext.performanceOverlayModel
        )
    }
}

private struct PerformanceSettingsViewContent: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var perf: PerformanceOverlayModel

    var body: some View {
        Form {
            Section(header: Text(t("Performance"))) {
                HStack {
                    Text("app.launch")
                    Spacer()
                    Text(perf.lastAppLaunchText)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("to first.ui")
                    Spacer()
                    Text(perf.launchToFirstUIText)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("to first.webview")
                    Spacer()
                    Text(perf.launchToFirstWebViewText)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    Text("discarded→active")
                    Spacer()
                    Text(perf.lastTabRestoreText)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    Text("memory.received")
                    Spacer()
                    Text(perf.lastMemoryPressureText)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("memory.mitigation")
                    Spacer()
                    Text(perf.memoryMitigationText)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(t("Performance"))
        .onAppear {
            perf.start()
        }
        .onDisappear {
            perf.stop()
        }
    }

    // MARK: - Localization (TH / EN)
    private func t(_ key: String) -> String {
        switch settings.language {
        case .th:
            return [
                "Performance": "ประสิทธิภาพ"
            ][key] ?? key
        case .en:
            return key
        }
    }
}
