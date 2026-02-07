import Foundation
import WebKit
import SafariLikeCoreKit
public struct ReaderExtractedContent: Equatable {
    public let title: String
    public let contentHTML: String
}
@MainActor
public enum ReaderContentExtractor {
    public static func isReaderAvailable(in webView: WKWebView) async -> Bool {
        do {
            let result = try await webView.evaluateJavaScriptAsync(Self.availabilityScript)
            return (result as? Bool) ?? false
        } catch {
            return false
        }
    }
    public static func extract(in webView: WKWebView) async throws -> ReaderExtractedContent {
        let result = try await webView.evaluateJavaScriptAsync(Self.extractScript)
        guard let json = result as? String, let data = json.data(using: .utf8) else {
            throw ReaderError.invalidResult
        }
        let decoded = try JSONDecoder().decode(ExtractPayload.self, from: data)
        guard decoded.available, let html = decoded.contentHTML, !html.isEmpty else {
            throw ReaderError.notAvailable
        }
        return ReaderExtractedContent(
            title: decoded.title ?? "",
            contentHTML: html
        )
    }
    // MARK: - Errors
    public enum ReaderError: Error {
        case invalidResult
        case notAvailable
    }
    // MARK: - JS payload
    private struct ExtractPayload: Codable {
        let available: Bool
        let title: String?
        let contentHTML: String?
    }
    // MARK: - Scripts
    private static let availabilityScript: String = Self.buildScript(mode: "availability")
    private static let extractScript: String = Self.buildScript(mode: "extract")
    private static func buildScript(mode: String) -> String {
        // NOTE: Keep this lightweight (no external Readability.js).
        // Heuristics:
        // - Prefer <article>, then <main>/<role=main>, then common content containers.
        // - Score candidates by text length + paragraph count, penalize link density and "noise" classes.
        return #"""
        (function() {
          try {
            function textLen(el) {
              if (!el) return 0;
              return (el.innerText || '').replace(/\s+/g,' ').trim().length;
            }
            function linkDensity(el) {
              if (!el) return 0;
              var text = (el.innerText || '');
              var linkText = '';
              var links = el.getElementsByTagName('a');
              for (var i = 0; i < links.length; i++) {
                linkText += (links[i].innerText || '') + ' ';
              }
              var tl = text.replace(/\s+/g,' ').trim().length;
              var ll = linkText.replace(/\s+/g,' ').trim().length;
              if (tl === 0) return 0;
              return ll / tl;
            }
            function isNoise(el) {
              if (!el) return true;
              var s = ((el.getAttribute('class') || '') + ' ' + (el.getAttribute('id') || '')).toLowerCase();
              return /(nav|menu|header|footer|sidebar|aside|ads|ad-|advert|promo|related|share|subscribe|cookie|banner|comment)/.test(s);
            }
            function candidateScore(el) {
              if (!el) return -1e9;
              var len = textLen(el);
              if (len < 200) return -1e9;
              var p = el.getElementsByTagName('p').length;
              var ld = linkDensity(el);
              var noisePenalty = isNoise(el) ? 500 : 0;
              return (len + p * 50) - (ld * 800) - noisePenalty;
            }
            function findCandidate() {
              var best = null;
              var bestScore = -1e9;
              var article = document.querySelector('article');
              if (article && textLen(article) >= 400) {
                best = article;
                bestScore = candidateScore(article);
              }
              var selectors = ['main', '[role=main]', '#content', '.content', '.post', '.post-content', '.entry-content', '.article', '.story', '.main', '.container'];
              for (var si = 0; si < selectors.length; si++) {
                var nodes = document.querySelectorAll(selectors[si]);
                for (var i = 0; i < nodes.length; i++) {
                  var s = candidateScore(nodes[i]);
                  if (s > bestScore) { bestScore = s; best = nodes[i]; }
                }
              }
              // Fallback: scan common block elements.
              var blocks = document.querySelectorAll('div, section');
              for (var j = 0; j < blocks.length; j++) {
                var b = blocks[j];
                if (b.closest && b.closest('nav, header, footer, aside')) continue;
                var sc = candidateScore(b);
                if (sc > bestScore) { bestScore = sc; best = b; }
              }
              return best;
            }
            function sanitize(cloneRoot) {
              if (!cloneRoot) return cloneRoot;
              var kill = cloneRoot.querySelectorAll('script, style, noscript, nav, header, footer, aside, form, iframe, button, input, textarea, select, svg, canvas');
              for (var i = 0; i < kill.length; i++) {
                kill[i].remove();
              }
              var all = cloneRoot.querySelectorAll('*');
              for (var j = 0; j < all.length; j++) {
                var el = all[j];
                var s = ((el.getAttribute('class') || '') + ' ' + (el.getAttribute('id') || '')).toLowerCase();
                if (/(nav|menu|header|footer|sidebar|aside|ads|ad-|advert|promo|related|share|subscribe|cookie|banner|comment)/.test(s)) {
                  el.remove();
                }
              }
              return cloneRoot;
            }
            var cand = findCandidate();
            var available = !!cand && textLen(cand) >= 500 && cand.getElementsByTagName('p').length >= 2;
            if ('\#(mode)' === 'availability') {
              return available;
            }
            if (!available) {
              return JSON.stringify({ available: false, title: document.title || '', contentHTML: null });
            }
            var clone = cand.cloneNode(true);
            sanitize(clone);
            var title = '';
            var h1 = document.querySelector('h1');
            if (h1 && (h1.innerText || '').trim().length > 0) title = (h1.innerText || '').trim();
            if (!title) title = (document.title || '').trim();
            return JSON.stringify({ available: true, title: title, contentHTML: clone.innerHTML });
          } catch (e) {
            if ('\#(mode)' === 'availability') { return false; }
            return JSON.stringify({ available: false, title: document.title || '', contentHTML: null });
          }
        })();
        """#
    }
}
