import SwiftUI
import SafariLikeContracts
import SafariLikeCoreKit
struct WebsiteSettingsView: View {
    @ObservedObject var vm: SplitBrowserViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var chrome: BrowserChromeState
    #if DEBUG
    @State private var isAutofillDebugPresented: Bool = false
    #endif
    @State private var zoom: Double = 1.0
    @State private var userAgent: WebsitePreferences.UserAgentMode = .mobile
    @State private var readerDefault: Bool = false
    @State private var javaScriptEnabled: Bool = true
    @State private var contentBlockingEnabled: Bool = true
    @State private var autofillEnabled: Bool = true
    @State private var userScriptsEnabledForSite: Bool = true
    @State private var userScriptsControlsEnabled: Bool = true
    @State private var cameraPermission: WebsitePreferences.PermissionSetting = .ask
    @State private var microphonePermission: WebsitePreferences.PermissionSetting = .ask
    @State private var locationPermission: WebsitePreferences.PermissionSetting = .ask
    @State private var readerFontSizePercent: Double = 100
    @State private var readerFontFamily: WebsitePreferences.ReaderFontFamily = .system
    @State private var readerTheme: WebsitePreferences.ReaderTheme = .system
    private var host: String? {
        vm.activeURLString.flatMap { URL(string: $0)?.host }
    }

    private var websiteDataProfile: WebsiteDataProfile {
        vm.isPrivateMode ? .private : .regular
    }
    var body: some View {
        NavigationView {
            Form {
                if let host = host {
                    Section(header: Text("Settings for \(host)")) {
                        VStack(alignment: .leading) {
                            Text("Zoom Level")
                                .font(.headline)
                            Slider(value: $zoom, in: 0.5...2.0, step: 0.1) {
                                Text("Zoom")
                            } minimumValueLabel: {
                                Text("50%")
                            } maximumValueLabel: {
                                Text("200%")
                            }
                            Text(String(format: "%.0f%%", zoom * 100))
                                .foregroundColor(.secondary)
                        }
                        Picker("User Agent", selection: $userAgent) {
                            ForEach(WebsitePreferences.UserAgentMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        Toggle("JavaScript", isOn: $javaScriptEnabled)
                        Toggle("Content Blocking", isOn: $contentBlockingEnabled)
                        Toggle("Autofill", isOn: $autofillEnabled)
                    }

                    Section(header: Text("User Scripts")) {
                        Toggle("Enable User Scripts on This Site", isOn: $userScriptsEnabledForSite)
                            .disabled(!userScriptsControlsEnabled)
                        if !userScriptsControlsEnabled {
                            Text(vm.isPrivateMode ? "User scripts are disabled in Private mode by default." : "User scripts are currently disabled by policy.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }

                        NavigationLink("Manage User Scripts") {
                            UserScriptsManagerView(
                                userScriptStore: vm.userScriptStore,
                                isPrivateMode: vm.isPrivateMode
                            )
                        }
                    }

                    Section(header: Text("Website Data")) {
                        Button("Manage Website Data") {
                            chrome.isWebsiteDataPresented = true
                        }

                        Button(role: .destructive) {
                            Task {
                                await clearWebsiteData(for: host)
                            }
                        } label: {
                            Text("Remove Website Data for This Website")
                        }
                        .disabled(websiteDataProfile == .private)
                    }
                    Section(header: Text("Reader")) {
                        Toggle("Reader Mode by Default", isOn: $readerDefault)
                        Picker("Reader Theme", selection: $readerTheme) {
                            ForEach(WebsitePreferences.ReaderTheme.allCases, id: \.self) { theme in
                                Text(theme.displayName).tag(theme)
                            }
                        }
                        Picker("Reader Font", selection: $readerFontFamily) {
                            ForEach(WebsitePreferences.ReaderFontFamily.allCases, id: \.self) { family in
                                Text(family.displayName).tag(family)
                            }
                        }
                        VStack(alignment: .leading) {
                            Text("Reader Font Size")
                                .font(.headline)
                            Slider(value: $readerFontSizePercent, in: 70...160, step: 5) {
                                Text("Reader Font Size")
                            } minimumValueLabel: {
                                Text("70%")
                            } maximumValueLabel: {
                                Text("160%")
                            }
                            Text("\(Int(readerFontSizePercent))%")
                                .foregroundColor(.secondary)
                        }
                    }
                    Section(header: Text("Permissions")) {
                        Picker("Camera", selection: $cameraPermission) {
                            ForEach(WebsitePreferences.PermissionSetting.allCases, id: \.self) { setting in
                                Text(setting.displayName).tag(setting)
                            }
                        }
                        Picker("Microphone", selection: $microphonePermission) {
                            ForEach(WebsitePreferences.PermissionSetting.allCases, id: \.self) { setting in
                                Text(setting.displayName).tag(setting)
                            }
                        }
                        Picker("Location", selection: $locationPermission) {
                            ForEach(WebsitePreferences.PermissionSetting.allCases, id: \.self) { setting in
                                Text(setting.displayName).tag(setting)
                            }
                        }
                    }
                    Section {
                        Button("Reset to Defaults") {
                            zoom = 1.0
                            userAgent = .mobile
                            readerDefault = false
                            javaScriptEnabled = true
                            contentBlockingEnabled = true
                            autofillEnabled = true
                            cameraPermission = .ask
                            microphonePermission = .ask
                            locationPermission = .ask
                            userScriptsEnabledForSite = true
                            saveSettings()
                        }
                        .foregroundColor(.red)
                    }

                    #if DEBUG
                    Section(header: Text("Debug")) {
                        Button("Autofill Debug") {
                            isAutofillDebugPresented = true
                        }
                    }
                    #endif
                } else {
                    Section {
                        Text("No website loaded")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Website Settings")
            .navigationBarItems(trailing: Button("Done") {
                self.saveSettings()
                self.dismiss()
            })
            .onAppear {
                self.loadCurrentSettings()
            }
            #if DEBUG
            .sheet(isPresented: $isAutofillDebugPresented) {
                AutofillDebugView(vm: vm)
            }
            #endif
        }
    }
    private func loadCurrentSettings() {
        guard let host = host else { return }
        let prefs = vm.websitePreferencesStore.getPreferences(for: host)
        zoom = prefs.zoom
        userAgent = prefs.userAgent
        readerDefault = prefs.readerDefault
        javaScriptEnabled = prefs.javaScriptEnabled
        contentBlockingEnabled = prefs.contentBlockingEnabled
        autofillEnabled = prefs.autofillEnabled
        cameraPermission = prefs.cameraPermission
        microphonePermission = prefs.microphonePermission
        locationPermission = prefs.locationPermission
        readerFontSizePercent = Double(prefs.readerFontSizePercent)
        readerFontFamily = prefs.readerFontFamily
        readerTheme = prefs.readerTheme

        let profile: UserScriptProfile = vm.isPrivateMode ? .private : .regular
        Task { @MainActor in
            let policy = await vm.userScriptStore.policy(profile: profile)
            let siteKey = SiteKey(host: host).storageKey
            let siteOverride = policy.perSiteOverrides[siteKey]
            userScriptsEnabledForSite = siteOverride ?? true
            userScriptsControlsEnabled = policy.globalEnabled && (!vm.isPrivateMode || policy.privateModeEnabled)
        }
    }
    private func saveSettings() {
        guard let host = host else { return }
        var prefs = vm.websitePreferencesStore.getPreferences(for: host)
        prefs.zoom = zoom
        prefs.userAgent = userAgent
        prefs.prefersDesktop = (userAgent == .desktop)
        prefs.readerDefault = readerDefault
        prefs.javaScriptEnabled = javaScriptEnabled
        prefs.contentBlockerEnabled = contentBlockingEnabled
        prefs.autofillEnabled = autofillEnabled
        prefs.cameraPermission = cameraPermission
        prefs.microphonePermission = microphonePermission
        prefs.locationPermission = locationPermission
        prefs.readerFontSizePercent = Int(readerFontSizePercent.rounded())
        prefs.readerFontFamily = readerFontFamily
        prefs.readerTheme = readerTheme
        vm.websitePreferencesStore.setPreferences(prefs, for: host)
        vm.applyWebsitePreferencesForActiveHost()
        vm.applyReaderPreferencesForActiveHost()

        let profile: UserScriptProfile = vm.isPrivateMode ? .private : .regular
        Task { @MainActor in
            await vm.userScriptStore.setSiteOverride(siteKey: SiteKey(host: host), enabled: userScriptsEnabledForSite, profile: profile)
        }
    }

    private func clearWebsiteData(for host: String) async {
        do {
            try await vm.websiteDataService.clear(
                request: ClearWebsiteDataRequest(
                    profile: websiteDataProfile,
                    scope: .site(siteKey: SiteKey(host: host))
                )
            )
        } catch {
            // Best-effort; UI intentionally silent for now.
        }
    }
}
