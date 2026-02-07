import Foundation
import SafariLikeContracts
import WebKit

/// Centralized, deterministic media/autoplay configuration for WKWebView.
///
/// Goals:
/// - Keep behavior consistent across all WKWebView instances.
/// - Apply as *primary* behavior at WKWebViewConfiguration creation time.
/// - Allow runtime policy bridges to be best-effort fallbacks only.
@MainActor
public enum WebViewMediaPolicy {
    /// Locked, app-wide defaults for media playback behavior.
    ///
    /// Important: This should be applied *before* constructing WKWebView.
    public static func applyMediaDefaults(to configuration: WKWebViewConfiguration) {
        #if os(iOS)
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        #endif

        // Safari-like default: require user gesture for autoplay unless explicitly allowed.
        if #available(iOS 10.0, *) {
            if configuration.mediaTypesRequiringUserActionForPlayback != .all {
                configuration.mediaTypesRequiringUserActionForPlayback = .all
            }
        }
    }

    public static func desiredMediaTypesRequiringUserActionForPlayback(
        allowAutoplay: Bool
    ) -> WKAudiovisualMediaTypes {
        // Empty set = no user action required.
        allowAutoplay ? [] : .all
    }

    /// Applies the autoplay policy to a configuration.
    /// - Returns: true if the configuration was mutated.
    public static func applyAutoplayPolicy(
        to configuration: WKWebViewConfiguration,
        allowAutoplay: Bool
    ) -> Bool {
        guard #available(iOS 10.0, *) else { return false }
        let desired = desiredMediaTypesRequiringUserActionForPlayback(allowAutoplay: allowAutoplay)
        if configuration.mediaTypesRequiringUserActionForPlayback == desired {
            return false
        }
        configuration.mediaTypesRequiringUserActionForPlayback = desired
        return true
    }

    /// Resolves whether autoplay should be allowed for a given URL.
    ///
    /// This is intentionally host-based to match the underlying preferences store.
    public static func allowAutoplay(
        for url: URL,
        websitePreferencesProvider: (any WebsitePreferencesProviding)?
    ) -> Bool {
        let host = url.host ?? ""
        guard host.isEmpty == false else { return false }
        let prefs = websitePreferencesProvider?.getPreferences(for: host)
        return (prefs?.allowsMediaAutoplay ?? false) || (prefs?.allowsAudioAutoplay ?? false)
    }
}
