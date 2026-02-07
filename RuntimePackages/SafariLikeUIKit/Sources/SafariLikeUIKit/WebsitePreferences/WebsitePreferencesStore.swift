import Foundation
import WebKit
import Combine
import SafariLikeContracts
import SafariLikeCoreKit

// MARK: - UI Layer: Website Preferences Store with WebKit Integration

/// Per-website preferences store (Safari-style "AA" menu) with UIKit/WebKit integration.
///
/// **Architecture:**
/// - Core: JSON persistence and preference lookup (domain -> preferences)
/// - UIKit: Applies preferences to WKWebViewConfiguration objects
///
/// **Threading:**
/// - @MainActor for UI/WebKit integration
/// - Async file I/O through JSONFileStoreActor
///
/// **Protocol Conformance:**
/// Conforms to WebsitePreferencesProviding for Core layer abstraction.
/// Additional methods expose WebKit integration for UI layer consumers.
@MainActor
public final class WebsitePreferencesStore: ObservableObject, WebsitePreferencesProviding, WebsitePreferencesApplying {

    /// Legacy preferences structure (for backward compatibility).
    /// This represents the older "zoom + desktop + reader" model.
    public struct LegacyPreferences: Codable, Equatable, Sendable {
        public var zoom: Double
        public var prefersDesktop: Bool
        public var readerDefault: Bool

        public init(zoom: Double = 1.0, prefersDesktop: Bool = false, readerDefault: Bool = false) {
            self.zoom = zoom
            self.prefersDesktop = prefersDesktop
            self.readerDefault = readerDefault
        }
    }

    // MARK: - Public State

    /// Published mapping of domain → legacy preferences for backward compatibility.
    @Published public private(set) var legacyMap: [String: LegacyPreferences]

    // MARK: - Internal Storage

    /// Internal storage of full WebsitePreferences (core model).
    private var preferencesMap: [String: WebsitePreferences] = [:]

    private let filename: String
    private var loadTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private let fileStore = JSONFileStoreActor()

    // MARK: - Initialization

    public init(filename: String = "website-preferences.json") {
        self.filename = filename
        self.legacyMap = [:]
        let fileStore = self.fileStore
        let filename = self.filename
        loadTask = Task {
            // Load file as either the new full map OR legacy map.
            // We intentionally keep this logic here (UI layer) because it owns
            // persistence format evolution.

            let full = await fileStore.load(filename: filename, defaultValue: Dictionary<String, WebsitePreferences>())
            if !full.isEmpty {
                await MainActor.run { [weak self] in
                    guard let self, !Task.isCancelled else { return }
                    self.preferencesMap = full
                    self.legacyMap = self.buildLegacyMap(from: full)
                }
                return
            }

            // Fallback: try legacy map and migrate.
            let legacy = await fileStore.load(filename: filename, defaultValue: Dictionary<String, LegacyPreferences>())
            await MainActor.run { [weak self] in
                guard let self, !Task.isCancelled else { return }
                self.legacyMap = legacy

                var migrated: [String: WebsitePreferences] = [:]
                for (domain, value) in legacy {
                    var prefs = WebsitePreferences.defaults(for: domain)
                    prefs.zoom = value.zoom
                    prefs.prefersDesktop = value.prefersDesktop
                    prefs.userAgent = value.prefersDesktop ? .desktop : .mobile
                    prefs.readerDefault = value.readerDefault
                    migrated[domain] = prefs
                }
                self.preferencesMap = migrated
            }
        }
    }

    deinit {
        // Cancel any in-flight persistence tasks to avoid orphaned work
        loadTask?.cancel()
        saveTask?.cancel()
    }

    // MARK: - WebsitePreferencesProviding Protocol Conformance

    /// Retrieves WebsitePreferences for a domain.
    ///
    /// - Parameter domain: The website domain
    /// - Returns: Stored preferences or defaults if not previously set
    public func getPreferences(for domain: String) -> WebsitePreferences {
        guard !domain.isEmpty else { return WebsitePreferences(domain: domain) }
        
        if let existing = preferencesMap[domain] {
            return existing
        }
        
        // Try to migrate from legacy preferences if available
        if let legacy = legacyMap[domain] {
            var migrated = WebsitePreferences.defaults(for: domain)
            // Migrate legacy UI fields into the core model so that
            // SplitBrowserStateGlue and WebsiteSettingsView can operate
            // purely on WebsitePreferences via the protocol.
            migrated.zoom = legacy.zoom
            migrated.prefersDesktop = legacy.prefersDesktop
            migrated.readerDefault = legacy.readerDefault
            preferencesMap[domain] = migrated
            return migrated
        }
        
        return WebsitePreferences.defaults(for: domain)
    }

    /// Stores updated preferences for a domain.
    ///
    /// - Parameters:
    ///   - preferences: The preferences to store
    ///   - domain: The website domain
    public func setPreferences(_ preferences: WebsitePreferences, for domain: String) {
        guard !domain.isEmpty else { return }
        preferencesMap[domain] = preferences
        // Keep legacy map updated for backward compatibility callers.
        legacyMap[domain] = LegacyPreferences(
            zoom: preferences.zoom,
            prefersDesktop: preferences.userAgent == .desktop,
            readerDefault: preferences.readerDefault
        )
        scheduleSave()
    }

    /// Returns all stored preference records.
    ///
    /// - Returns: Array of all stored WebsitePreferences
    public func allPreferences() -> [WebsitePreferences] {
        Array(preferencesMap.values)
    }

    /// Removes preferences for a domain.
    ///
    /// - Parameter domain: The domain to clear
    public func clearPreferences(for domain: String) {
        guard !domain.isEmpty else { return }
        preferencesMap.removeValue(forKey: domain)
        legacyMap.removeValue(forKey: domain)
        scheduleSave()
    }

    /// Removes all stored preferences (factory reset).
    public func clearAllPreferences() {
        preferencesMap.removeAll()
        legacyMap.removeAll()
        scheduleSave()
    }

    // MARK: - UIKit Integration: WebKit Configuration

    /// Applies stored preferences to a WKWebViewConfiguration.
    ///
    /// - Parameters:
    ///   - configuration: The WKWebViewConfiguration to modify
    ///   - domain: The website domain
    ///
    /// **Note:** This method is UIKit-specific. Core layer uses WebsitePreferencesProviding
    /// protocol without knowledge of WKWebViewConfiguration.
    public func applyPreferences(to configuration: WKWebViewConfiguration, for domain: String) {
        let prefs = getPreferences(for: domain)
        
        // JavaScript - use WKWebpagePreferences (replaces deprecated WKPreferences.javaScriptEnabled)
        let webpagePreferences = WKWebpagePreferences()
        webpagePreferences.allowsContentJavaScript = prefs.javaScriptEnabled
        configuration.defaultWebpagePreferences = webpagePreferences

        // Note: Most per-site settings must be applied per-navigation (WKNavigationDelegate)
        // or per-request (e.g. user agent), not via WKWebViewConfiguration.
    }

    /// Applies preferences to a WKWebViewConfiguration using a non-optional host.
    ///
    /// - Parameters:
    ///   - configuration: The WKWebViewConfiguration to modify
    ///   - host: The website host/domain
    ///
    /// This is a convenience overload to make TabWebStore-style callers explicit
    /// when they already have a non-optional host string.
    public func applyPreferences(to configuration: WKWebViewConfiguration, forHost host: String) {
        guard !host.isEmpty else { return }
        applyPreferences(to: configuration, for: host)
    }

    /// Applies preferences to a WKWebViewConfiguration using host (backward compatible).
    ///
    /// - Parameters:
    ///   - configuration: The WKWebViewConfiguration to modify
    ///   - host: The website host/domain
    ///
    /// **Note:** Convenience method for backward compatibility with legacy code.
    public func applyPreferences(to configuration: WKWebViewConfiguration, forHost host: String?) {
        guard let host, !host.isEmpty else { return }
        applyPreferences(to: configuration, forHost: host)
    }

    // MARK: - Backward Compatibility: Legacy Preferences API

    /// Legacy method: Retrieves preferences for a host.
    ///
    /// - Parameter host: The website host/domain
    /// - Returns: Legacy Preferences structure
    ///
    /// **Note:** This method is maintained for backward compatibility.
    /// New code should use WebsitePreferencesProviding protocol.
    public func preferences(forHost host: String?) -> LegacyPreferences {
        guard let host, !host.isEmpty else { return LegacyPreferences() }
        return legacyMap[host] ?? LegacyPreferences()
    }

    /// Legacy method: Stores preferences for a host.
    ///
    /// - Parameters:
    ///   - prefs: The legacy Preferences to store
    ///   - host: The website host/domain
    ///
    /// **Note:** This method is maintained for backward compatibility.
    /// New code should use WebsitePreferencesProviding protocol.
    public func set(_ prefs: LegacyPreferences, forHost host: String?) {
        guard let host, !host.isEmpty else { return }
        legacyMap[host] = prefs
        scheduleSave()
    }

    /// Legacy method: Resets preferences for a host.
    ///
    /// - Parameter host: The website host/domain
    ///
    /// **Note:** This method is maintained for backward compatibility.
    public func reset(forHost host: String?) {
        guard let host, !host.isEmpty else { return }
        legacyMap.removeValue(forKey: host)
        scheduleSave()
    }

    // MARK: - Internal Persistence

    private func scheduleSave() {
        saveTask?.cancel()
        let filename = self.filename
        saveTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return }
            guard !Task.isCancelled, let self else { return }
            // Persist full preferences map (new format).
            // This is backward compatible at the model level (WebsitePreferences init(from:)).
            let snapshot = self.preferencesMap
            await self.fileStore.save(filename: filename, value: snapshot)
        }
    }

    private func buildLegacyMap(from full: [String: WebsitePreferences]) -> [String: LegacyPreferences] {
        var out: [String: LegacyPreferences] = [:]
        for (domain, prefs) in full {
            out[domain] = LegacyPreferences(
                zoom: prefs.zoom,
                prefersDesktop: prefs.userAgent == .desktop,
                readerDefault: prefs.readerDefault
            )
        }
        return out
    }
}

// MARK: - Preview Support (Internal)

extension WebsitePreferencesStore {
    static let preview: WebsitePreferencesStore = {
        let store = WebsitePreferencesStore(filename: "preview-preferences.json")
        return store
    }()
}
