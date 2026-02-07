import SwiftUI
import SafariLikeKit

struct SettingsView: View {

    // App-level settings (internal by design)
    @ObservedObject var settings: AppSettings

    // Callback to App layer
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.browserWindowID) private var browserWindowID
    @Environment(\.browserRuntime) private var browserRuntime

    @StateObject private var pluginViewModel = PluginManagerViewModel()

    @StateObject private var menuModel = SettingsMenuModel()

    @EnvironmentObject private var sceneContext: SceneRuntimeContext

    init(
        settings: AppSettings,
        onDone: @escaping () -> Void
    ) {
        self.settings = settings
        self.onDone = onDone
    }

    var body: some View {
        SettingsViewContent(
            settings: settings,
            onDone: onDone,
            perf: sceneContext.performanceOverlayModel,
            menuModel: menuModel,
            pluginViewModel: pluginViewModel
        )
    }
}

private struct SettingsViewContent: View {
    @ObservedObject var settings: AppSettings
    let onDone: () -> Void
    @ObservedObject var perf: PerformanceOverlayModel
    @ObservedObject var menuModel: SettingsMenuModel
    @ObservedObject var pluginViewModel: PluginManagerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.browserWindowID) private var browserWindowID
    @Environment(\.browserRuntime) private var browserRuntime
    @EnvironmentObject private var sceneContext: SceneRuntimeContext

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack(path: $menuModel.path) {
                formContent
                    .navigationDestination(for: SettingsMenuModel.SettingsDestination.self) { destination in
                        switch destination {
                        case .performance:
                            PerformanceSettingsView(settings: settings)
					case .networkDiagnostics:
						NetworkDiagnosticsView()
                        }
                    }
            }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { doneButton }
                }
        } else {
            NavigationView { formContent }
                .navigationViewStyle(.stack)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) { doneButton }
                }
        }
    }

    private var formContent: some View {
        Form {
            Section(header: Text(t("Appearance"))) {
                Toggle(
                    t("Dark Mode"),
                    isOn: $settings.darkModeEnabled
                )
            }

            Section(header: Text(t("Language"))) {
                Picker(
                    t("Language"),
                    selection: $settings.language
                ) {
                    ForEach(AppSettings.Language.allCases) { lang in
                        Text(lang.title)
                            .tag(lang)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text(t("Privacy"))) {
                Toggle(
                    t("Content Blocker"),
                    isOn: $settings.contentBlockerEnabled
                )

                Toggle(
                    t("Allow Autofill"),
                    isOn: $settings.autofillEnabled
                )
                Text(t("Content Blocker Description"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text(t("Search"))) {
                Picker(
                    t("Search Engine"),
                    selection: $settings.searchEngine
                ) {
                    ForEach(AppSettings.SearchEngine.allCases) { engine in
                        Text(engine.title)
                            .tag(engine)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text(t("Diagnostics"))) {
                Toggle(
                    t("Enable Diagnostics"),
                    isOn: $settings.diagnosticsEnabled
                )

				if #available(iOS 16.0, *) {
					Button {
						menuModel.navigate(to: .networkDiagnostics)
					} label: {
						Label(t("Network Diagnostics"), systemImage: "antenna.radiowaves.left.and.right")
					}
					.buttonStyle(.plain)
                } else {
                    NavigationLink(destination: NetworkDiagnosticsView()) {
                        Label(t("Network Diagnostics"), systemImage: "antenna.radiowaves.left.and.right")
                    }
				}

                Toggle(
                    t("Show Policy Decision Overlay"),
                    isOn: $settings.policyOverlayEnabled
                )
                .disabled(!settings.diagnosticsEnabled)
                .onChange(of: settings.policyOverlayEnabled) { newValue in
                    sceneContext.navigationPolicyOverlayModel.setVisible(newValue)
                }

                Text(t("Diagnostics Description"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text(t("Performance"))) {
                if #available(iOS 16.0, *) {
                    Button {
                        menuModel.navigate(to: .performance)
                    } label: {
                        Label(t("Performance"), systemImage: "speedometer")
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink(destination: PerformanceSettingsView(settings: settings)) {
                        Label(t("Performance"), systemImage: "speedometer")
                    }
                }
            }

            Section(header: Text(t("Plugins"))) {
                if browserWindowID == nil {
                    Text(t("Plugins Missing WindowID"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if pluginViewModel.pluginIDs.isEmpty {
                    Text(t("Plugins None Registered"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(pluginViewModel.pluginIDs, id: \.self) { id in
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(
                                id,
                                isOn: Binding(
                                    get: { pluginViewModel.isEnabled(id) },
                                    set: { newValue in
                                        Task { @MainActor in
                                            await pluginViewModel.setEnabled(newValue, pluginID: id)
                                        }
                                    }
                                )
                            )
                            .disabled(!pluginViewModel.isUIEnabled)

                            DisclosureGroup(t("Plugin Permissions")) {
                                ForEach(PluginPermissions.all, id: \.self) { permission in
                                    Toggle(
                                        permissionTitle(permission),
                                        isOn: Binding(
                                            get: { pluginViewModel.isPermissionGranted(permission, pluginID: id) },
                                            set: { newValue in
                                                Task { @MainActor in
                                                    await pluginViewModel.setPermission(newValue, permission: permission, pluginID: id)
                                                }
                                            }
                                        )
                                    )
                                    .disabled(!pluginViewModel.isUIEnabled)
                                }
                            }
                            .font(.caption)
                        }
                    }
                }

                if browserWindowID != nil && !pluginViewModel.isUIEnabled {
                    Text(t("Plugins Missing Runtime"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(t("Plugins Description"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

        }
        .navigationTitle(t("Settings"))
        .onAppear {
            pluginViewModel.configure(windowID: browserWindowID, runtime: browserRuntime)
            if settings.diagnosticsEnabled {
                perf.start()
            }
        }
        .onDisappear {
            perf.stop()
        }
        .task(id: browserWindowID?.value) {
            pluginViewModel.configure(windowID: browserWindowID, runtime: browserRuntime)
        }
    }

    private var doneButton: some View {
        Button(t("Done")) {
            onDone()
            dismiss()
        }
    }

    // MARK: - Localization (TH / EN)
    private func t(_ key: String) -> String {
        switch settings.language {
        case .th:
            return [
                "Settings": "ตั้งค่า",
                "Done": "เสร็จสิ้น",
                "Appearance": "การแสดงผล",
                "Dark Mode": "โหมดมืด",
                "Language": "ภาษา",
                "Performance": "ประสิทธิภาพ",
                "Privacy": "ความเป็นส่วนตัว",
                "Content Blocker": "ตัวบล็อกเนื้อหา",
                "Content Blocker Description": "บล็อกโฆษณาและตัวติดตามเพื่อปกป้องความเป็นส่วนตัว",
                "Allow Autofill": "อนุญาตการกรอกอัตโนมัติ",
                "Search": "การค้นหา",
                "Search Engine": "เครื่องมือค้นหา",
                "Diagnostics": "การวินิจฉัย",
                "Enable Diagnostics": "เปิดใช้งานการวินิจฉัย",
				"Network Diagnostics": "การวินิจฉัยเครือข่าย",
                "Show Policy Decision Overlay": "แสดงโอเวอร์เลย์การตัดสินใจของนโยบาย",
                "Diagnostics Description": "บันทึกเหตุการณ์ภายในและตัวนับแบบไม่ระบุตัวตนเพื่อช่วยแก้ไขปัญหา (ไม่มีการติดตาม)",
                "Plugins": "ปลั๊กอิน",
                "Plugins Description": "ปลั๊กอินเป็นส่วนเสริมที่ติดมากับแอป (compile-time) และเปิด/ปิดได้แยกตามหน้าต่าง",
                "Plugin Permissions": "สิทธิ์ของปลั๊กอิน",
                "Plugins Missing WindowID": "ไม่พบ windowID สำหรับหน้าต่างนี้ จึงไม่สามารถจัดการปลั๊กอินได้",
                "Plugins Missing TabManager": "ไม่พร้อมใช้งาน: ไม่มีตัวจัดการแท็บสำหรับหน้าต่างนี้",
                "Plugins Missing Runtime": "ไม่พร้อมใช้งาน: ไม่มีรันไทม์สำหรับหน้าต่างนี้",
                "Plugins None Registered": "ไม่มีปลั๊กอินที่ลงทะเบียนไว้ในระบบ"
            ][key] ?? key

        case .en:
            return key
        }
    }

    private func permissionTitle(_ permission: PluginPermission) -> String {
        let key = PluginPermissions.key(permission)
        switch settings.language {
        case .th:
            switch key {
            case "navigationRead": return "อ่านเหตุการณ์นำทาง"
            case "navigationIntercept": return "ดัก/บล็อกการนำทาง"
            case "contentScripts": return "สคริปต์/สไตล์บนหน้าเว็บ"
            case "contentBlocking": return "บล็อกเนื้อหา (rule list)"
            case "downloads": return "ดาวน์โหลด"
            case "storage": return "จัดเก็บข้อมูล"
            default:
                return "สิทธิ์ไม่รู้จัก"
            }
        case .en:
            return key
        }
    }
}
