import Foundation
import WebKit
import SafariLikeContracts

/// Lightweight, reversible "reader-ish" mode.
///
/// Goals:
/// - CSS-only styling + optional clutter hiding heuristics.
/// - No DOM extraction, no overlay injection, no long-lived observers/timers.
/// - Reversible by removing a single style tag + html class.
@MainActor
public enum LightweightReaderModeController {
    private static let styleElementID = "sl-lite-reader-style"
    private static let enabledClass = "sl-lite-reader-enabled"

    public static func isReaderAvailable(in webView: WKWebView) async -> Bool {
        let script = """
        (function() {
          try {
            var root = document.querySelector('article, main') || document.body;
            if (!root) return false;
            var text = (root.innerText || '').trim();
            if (text.length < 800) return false;
            var words = text.split(/\\s+/).length;
            if (words < 250) return false;
            var pCount = root.querySelectorAll('p').length;
            if (pCount < 3) return false;
            return true;
          } catch (e) {
            return false;
          }
        })();
        """

        do {
            let result = try await webView.evaluateJavaScript(script)
            return (result as? Bool) ?? false
        } catch {
            return false
        }
    }

    public static func enable(in webView: WKWebView, preferences: WebsitePreferences) async throws {
        let css = readerCSS(preferences: preferences)
        let script = """
        (function() {
          var css = \(css.jsQuoted());
          var id = '\(styleElementID)';
          var style = document.getElementById(id);
          if (!style) {
            style = document.createElement('style');
            style.id = id;
            document.head.appendChild(style);
          }
          style.textContent = css;
          document.documentElement.classList.add('\(enabledClass)');
        })();
        """

        _ = try await webView.evaluateJavaScript(script)
    }

    public static func disable(in webView: WKWebView) async {
        let script = """
        (function() {
          var id = '\(styleElementID)';
          var style = document.getElementById(id);
          if (style && style.parentNode) style.parentNode.removeChild(style);
          document.documentElement.classList.remove('\(enabledClass)');
        })();
        """

        _ = try? await webView.evaluateJavaScript(script)
    }

    public static func updateStyleIfEnabled(in webView: WKWebView, preferences: WebsitePreferences) async {
        let css = readerCSS(preferences: preferences)
        let script = """
        (function() {
          if (!document.documentElement.classList.contains('\(enabledClass)')) return;
          var id = '\(styleElementID)';
          var style = document.getElementById(id);
          if (!style) return;
          style.textContent = \(css.jsQuoted());
        })();
        """

        _ = try? await webView.evaluateJavaScript(script)
    }

    private static func readerCSS(preferences: WebsitePreferences) -> String {
        let fontSize = max(70, min(160, preferences.readerFontSizePercent))
        let fontFamily = fontFamilyCSS(preferences.readerFontFamily)
        let theme = preferences.readerTheme

        func themeVars(_ theme: WebsitePreferences.ReaderTheme) -> (bg: String, fg: String, muted: String, link: String) {
          switch theme {
          case .dark:
            return (bg: "#0b0b0c", fg: "#f2f2f2", muted: "#b7b7b9", link: "#8ab4ff")
          case .sepia:
            return (bg: "#f4ecd8", fg: "#3b2f20", muted: "#6e5d45", link: "#0b57d0")
          case .light, .system:
            return (bg: "#ffffff", fg: "#1c1c1e", muted: "#6b6b6f", link: "#0b57d0")
          @unknown default:
            return (bg: "#ffffff", fg: "#1c1c1e", muted: "#6b6b6f", link: "#0b57d0") // fallback: safe default
          }
        }

        let vars = themeVars(theme)

        return """
        html.\(enabledClass), html.\(enabledClass) body {
          background: \(vars.bg) !important;
          color: \(vars.fg) !important;
        }

        html.\(enabledClass) body {
          font-family: \(fontFamily) !important;
          font-size: \(fontSize)% !important;
          line-height: 1.65 !important;
          letter-spacing: 0.01em;
          text-rendering: optimizeLegibility;
          -webkit-text-size-adjust: 100%;
        }

        html.\(enabledClass) a { color: \(vars.link) !important; }

        /* Clutter hiding heuristics (CSS-only) */
        html.\(enabledClass) :is(nav, header, footer, aside) {
          display: none !important;
        }

        /* Center and constrain readable regions */
        html.\(enabledClass) :is(article, main) {
          max-width: 740px;
          margin: 0 auto;
          padding: 18px 16px 60px;
        }

        /* Fallback: if no article/main, at least constrain body width */
        html.\(enabledClass) body {
          max-width: 900px;
          margin: 0 auto;
          padding: 12px 12px 60px;
        }

        html.\(enabledClass) :is(img, video) { max-width: 100% !important; height: auto !important; }
        html.\(enabledClass) blockquote { border-left: 3px solid \(vars.muted); padding-left: 1em; color: \(vars.muted); }
        """
    }

    private static func fontFamilyCSS(_ family: WebsitePreferences.ReaderFontFamily) -> String {
        switch family {
        case .serif:
          return "ui-serif, Georgia, 'Times New Roman', Times, serif"
        case .sansSerif:
          return "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', Helvetica, Arial, sans-serif"
        case .monospace:
          return "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', monospace"
        case .system:
          return "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', Helvetica, Arial, sans-serif"
        @unknown default:
          return "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', Helvetica, Arial, sans-serif" // fallback: system default
        }
    }
}

private extension String {
    func jsQuoted() -> String {
        // Minimal JS string quoting for embedding CSS in scripts.
        // Using JSON encoding keeps it robust.
        let data = try? JSONSerialization.data(withJSONObject: [self], options: [])
        let json = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
        // json is ["..."]; strip the brackets.
        return String(json.dropFirst().dropLast())
    }
}
