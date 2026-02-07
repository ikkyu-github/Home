import Foundation
import WebKit
import SafariLikeContracts
import SafariLikeCoreKit
@MainActor
public enum ReaderModeController {
    public static func enableReaderMode(in webView: WKWebView, preferences: WebsitePreferences) async throws {
        let extracted = try await ReaderContentExtractor.extract(in: webView)
        let payload = OverlayPayload(
            title: extracted.title,
            contentHTML: extracted.contentHTML,
            fontSizePercent: preferences.readerFontSizePercent,
            fontFamily: preferences.readerFontFamily.rawValue,
            theme: preferences.readerTheme.rawValue
        )
        let json = try payload.jsonString()
        let script = """
        (function() {
          var payload = \(json);
          function ensureStyleTag() {
            var id = 'sl-reader-style';
            var style = document.getElementById(id);
            if (!style) {
              style = document.createElement('style');
              style.id = id;
              document.head.appendChild(style);
            }
            return style;
          }
          function themeVars(theme) {
            // Colors tuned for readability; "system" uses light defaults.
            if (theme === 'dark') {
              return { bg: '#0b0b0c', fg: '#f2f2f2', muted: '#b7b7b9', link: '#8ab4ff', sepia: false };
            }
            if (theme === 'sepia') {
              return { bg: '#f4ecd8', fg: '#3b2f20', muted: '#6e5d45', link: '#0b57d0', sepia: true };
            }
            // light + system
            return { bg: '#ffffff', fg: '#1c1c1e', muted: '#6b6b6f', link: '#0b57d0', sepia: false };
          }
          function fontFamilyCSS(family) {
            if (family === 'serif') return "ui-serif, Georgia, 'Times New Roman', Times, serif";
            if (family === 'sansSerif') return "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', Helvetica, Arial, sans-serif";
            if (family === 'monospace') return "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', monospace";
            return "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', Helvetica, Arial, sans-serif";
          }
          function applyOverlayStyles(payload) {
            var vars = themeVars(payload.theme);
            var fs = Math.max(70, Math.min(160, payload.fontSizePercent || 100));
            var ff = fontFamilyCSS(payload.fontFamily);
            var style = ensureStyleTag();
            style.textContent = `
              html.sl-reader-enabled, html.sl-reader-enabled body {
                height: 100% !important;
                overflow: hidden !important;
                background: ${vars.bg} !important;
              }
              html.sl-reader-enabled body > :not(#sl-reader-overlay) {
                display: none !important;
              }
              #sl-reader-overlay {
                position: fixed;
                inset: 0;
                z-index: 2147483647;
                overflow: auto;
                -webkit-overflow-scrolling: touch;
                background: ${vars.bg};
                color: ${vars.fg};
              }
              #sl-reader-container {
                max-width: 740px;
                margin: 0 auto;
                padding: 24px 18px 60px;
                font-family: ${ff};
                font-size: ${fs}%;
                line-height: 1.6;
                letter-spacing: 0.01em;
              }
              #sl-reader-container h1 {
                font-size: 1.55em;
                line-height: 1.2;
                margin: 0 0 0.6em;
              }
              #sl-reader-container a { color: ${vars.link}; }
              #sl-reader-container img, #sl-reader-container video { max-width: 100%; height: auto; }
              #sl-reader-container p { margin: 0 0 1em; }
              #sl-reader-container pre, #sl-reader-container code {
                font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
                font-size: 0.95em;
              }
              #sl-reader-container blockquote {
                margin: 1em 0;
                padding: 0.2em 0 0.2em 1em;
                border-left: 3px solid ${vars.muted};
                color: ${vars.muted};
              }
            `;
          }
          var existing = document.getElementById('sl-reader-overlay');
          if (!existing) {
            // Persist scroll position so we can restore on disable.
            window.__slReaderScrollY = window.scrollY || 0;
            var overlay = document.createElement('div');
            overlay.id = 'sl-reader-overlay';
            var container = document.createElement('div');
            container.id = 'sl-reader-container';
            var title = document.createElement('h1');
            title.textContent = payload.title || '';
            var content = document.createElement('div');
            content.id = 'sl-reader-content';
            content.innerHTML = payload.contentHTML || '';
            container.appendChild(title);
            container.appendChild(content);
            overlay.appendChild(container);
            document.body.appendChild(overlay);
          } else {
            // Update content in-place (in case re-enable or settings change).
            var titleEl = document.querySelector('#sl-reader-container h1');
            if (titleEl) titleEl.textContent = payload.title || '';
            var contentEl = document.getElementById('sl-reader-content');
            if (contentEl) contentEl.innerHTML = payload.contentHTML || '';
          }
          document.documentElement.classList.add('sl-reader-enabled');
          applyOverlayStyles(payload);
          return true;
        })();
        """
        _ = try await webView.evaluateJavaScriptAsync(script)
    }
    public static func disableReaderMode(in webView: WKWebView) async {
        let script = """
        (function() {
          try {
            document.documentElement.classList.remove('sl-reader-enabled');
            var overlay = document.getElementById('sl-reader-overlay');
            if (overlay) overlay.remove();
            var style = document.getElementById('sl-reader-style');
            if (style) style.remove();
            var y = window.__slReaderScrollY;
            if (typeof y === 'number') {
              window.scrollTo(0, y);
            }
            return true;
          } catch (e) {
            return false;
          }
        })();
        """
        _ = try? await webView.evaluateJavaScriptAsync(script)
    }
    public static func updateReaderStyleIfEnabled(in webView: WKWebView, preferences: WebsitePreferences) async {
        let payload = OverlayStylePayload(
            fontSizePercent: preferences.readerFontSizePercent,
            fontFamily: preferences.readerFontFamily.rawValue,
            theme: preferences.readerTheme.rawValue
        )
        guard let json = try? payload.jsonString() else { return }
        let script = """
        (function() {
          try {
            if (!document.documentElement.classList.contains('sl-reader-enabled')) return false;
            var style = document.getElementById('sl-reader-style');
            if (!style) return false;
            var payload = \(json);
            // Reuse the enable() styling logic by calling enable with a no-op update.
            function themeVars(theme) {
              if (theme === 'dark') return { bg: '#0b0b0c', fg: '#f2f2f2', muted: '#b7b7b9', link: '#8ab4ff' };
              if (theme === 'sepia') return { bg: '#f4ecd8', fg: '#3b2f20', muted: '#6e5d45', link: '#0b57d0' };
              return { bg: '#ffffff', fg: '#1c1c1e', muted: '#6b6b6f', link: '#0b57d0' };
            }
            function fontFamilyCSS(family) {
              if (family === 'serif') return "ui-serif, Georgia, 'Times New Roman', Times, serif";
              if (family === 'sansSerif') return "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', Helvetica, Arial, sans-serif";
              if (family === 'monospace') return "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', monospace";
              return "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', Helvetica, Arial, sans-serif";
            }
            var vars = themeVars(payload.theme);
            var fs = Math.max(70, Math.min(160, payload.fontSizePercent || 100));
            var ff = fontFamilyCSS(payload.fontFamily);
            style.textContent = `
              html.sl-reader-enabled, html.sl-reader-enabled body {
                height: 100% !important;
                overflow: hidden !important;
                background: ${vars.bg} !important;
              }
              html.sl-reader-enabled body > :not(#sl-reader-overlay) {
                display: none !important;
              }
              #sl-reader-overlay {
                position: fixed;
                inset: 0;
                z-index: 2147483647;
                overflow: auto;
                -webkit-overflow-scrolling: touch;
                background: ${vars.bg};
                color: ${vars.fg};
              }
              #sl-reader-container {
                max-width: 740px;
                margin: 0 auto;
                padding: 24px 18px 60px;
                font-family: ${ff};
                font-size: ${fs}%;
                line-height: 1.6;
                letter-spacing: 0.01em;
              }
              #sl-reader-container h1 {
                font-size: 1.55em;
                line-height: 1.2;
                margin: 0 0 0.6em;
              }
              #sl-reader-container a { color: ${vars.link}; }
              #sl-reader-container img, #sl-reader-container video { max-width: 100%; height: auto; }
              #sl-reader-container p { margin: 0 0 1em; }
              #sl-reader-container pre, #sl-reader-container code {
                font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
                font-size: 0.95em;
              }
              #sl-reader-container blockquote {
                margin: 1em 0;
                padding: 0.2em 0 0.2em 1em;
                border-left: 3px solid ${vars.muted};
                color: ${vars.muted};
              }
            `;
            return true;
          } catch (e) {
            return false;
          }
        })();
        """
        _ = try? await webView.evaluateJavaScriptAsync(script)
    }
    // MARK: - Payloads
    private struct OverlayPayload: Codable {
        let title: String
        let contentHTML: String
        let fontSizePercent: Int
        let fontFamily: String
        let theme: String
        func jsonString() throws -> String {
            let data = try JSONEncoder().encode(self)
            guard let s = String(data: data, encoding: .utf8) else { throw EncodingError.invalidValue(self, .init(codingPath: [], debugDescription: "Unable to encode payload")) }
            return s
        }
    }
    private struct OverlayStylePayload: Codable {
        let fontSizePercent: Int
        let fontFamily: String
        let theme: String
        func jsonString() throws -> String {
            let data = try JSONEncoder().encode(self)
            guard let s = String(data: data, encoding: .utf8) else { throw EncodingError.invalidValue(self, .init(codingPath: [], debugDescription: "Unable to encode payload")) }
            return s
        }
    }
}
