import SwiftUI
import Combine
import SafariLikeKit
import SafariLikeContracts

@MainActor
final class AppSettings: ObservableObject {

    // MARK: - Language
    enum Language: String, CaseIterable, Identifiable {
        case th = "th"
        case en = "en"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .th: return "ไทย"
            case .en: return "English"
            }
        }
    }

    // MARK: - Search Engine
    enum SearchEngine: String, CaseIterable, Identifiable {
        case google = "google"
        case bing = "bing"
        case duckduckgo = "duckduckgo"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .google: return "Google"
            case .bing: return "Bing"
            case .duckduckgo: return "DuckDuckGo"
            }
        }

        var searchURL: URL {
            switch self {
            case .google: return SafariLikeContracts.DefaultURLs.SearchEngine.googleQuery
            case .bing: return SafariLikeContracts.DefaultURLs.SearchEngine.bingQuery
            case .duckduckgo: return SafariLikeContracts.DefaultURLs.SearchEngine.duckDuckGoQuery
            }
        }
    }

    // MARK: - Persistence (DO NOT TOUCH in init)
    @AppStorage("app.language")
    private var storedLanguage: String = Language.th.rawValue

    @AppStorage("app.darkMode")
    private var storedDarkMode: Bool = false

    @AppStorage("app.contentBlockerEnabled")
    private var storedContentBlockerEnabled: Bool = true

    @AppStorage("app.autofill.enabled")
    private var storedAutofillEnabled: Bool = true

    @AppStorage("app.searchEngine")
    private var storedSearchEngine: String = SearchEngine.google.rawValue

    #if DEBUG
    @AppStorage("app.diagnostics.enabled")
    private var storedDiagnosticsEnabled: Bool = true
    #else
    @AppStorage("app.diagnostics.enabled")
    private var storedDiagnosticsEnabled: Bool = false
    #endif

    @AppStorage("app.policy.overlay.enabled")
    private var storedPolicyOverlayEnabled: Bool = false

    // MARK: - Observable state (must have defaults)
    @Published var language: Language = .th
    @Published var darkModeEnabled: Bool = false
    @Published var contentBlockerEnabled: Bool = true
    @Published var autofillEnabled: Bool = true
    @Published var searchEngine: SearchEngine = .google
    @Published var diagnosticsEnabled: Bool = false
    @Published var policyOverlayEnabled: Bool = false

    // MARK: - Init
    init() {
        // ❗ ห้ามอ่าน AppStorage ตรงนี้
        // Swift rule: init ต้องจบก่อน
        loadFromStorage()
    }

    // MARK: - Load
    private func loadFromStorage() {
        let lang = Language(rawValue: storedLanguage) ?? .th
        language = lang
        darkModeEnabled = storedDarkMode
        contentBlockerEnabled = storedContentBlockerEnabled
        autofillEnabled = storedAutofillEnabled
        let engine = SearchEngine(rawValue: storedSearchEngine) ?? .google
        searchEngine = engine
        diagnosticsEnabled = storedDiagnosticsEnabled
        policyOverlayEnabled = storedPolicyOverlayEnabled
    }

    // MARK: - Save
    func sync() {
        storedLanguage = language.rawValue
        storedDarkMode = darkModeEnabled
        storedContentBlockerEnabled = contentBlockerEnabled
        storedAutofillEnabled = autofillEnabled
        storedSearchEngine = searchEngine.rawValue
        storedDiagnosticsEnabled = diagnosticsEnabled
        storedPolicyOverlayEnabled = policyOverlayEnabled
    }
}
