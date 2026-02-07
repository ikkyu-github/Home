import Foundation

/// Extracts context-aware "Related" links from the currently loaded page via JavaScript.
///
/// Notes:
/// - Intentionally defensive: pages can be messy, and WebKit JS can throw.
/// - Prefers anchors in main/article when possible.
/// - Filters out obvious chrome links (nav/footer/header/aside) to improve relevance.
/// - Scores links by distance to viewport center + text quality + same-host bias.
public enum RelatedLinkExtractor {

  public static func javascript(maxItems: Int = 24) -> String {
        // IMPORTANT: return a *single* expression that evaluates to a JSON string.
        // WebKit will pass it back as `String`.
        return """
        (function(){
          try {
            var MAX = \(maxItems);
            var currentHost = (location.host || '').toLowerCase();
            var h = window.innerHeight || 1;
            var minTop = -0.35 * h;
            var maxTop = 1.65 * h;
            var centerY = 0.5 * h;

            // Prefer content roots, but fall back safely.
            var root = document.querySelector('main,article,[role="main"]') || document.body || document.documentElement;

            // Skip obvious page chrome (menus, footers, headers, etc).
            var IGNORE = 'nav,footer,header,aside,form,[role="navigation"],[role="banner"],[role="contentinfo"],.nav,.navbar,.footer,.header,.menu,.sidebar';

            function isIgnored(el) {
              try { return !!(el && el.closest && el.closest(IGNORE)); } catch(e) { return false; }
            }

            function cleanText(s) {
              if (!s) return '';
              return ('' + s).replace(/\\s+/g,' ').trim();
            }

            function safeURL(href) {
              try { return new URL(href, location.href); } catch(e) { return null; }
            }

            var anchors = Array.from(root.querySelectorAll('a[href]'));
            var out = [];

            for (var i=0;i<anchors.length;i++) {
              var a = anchors[i];
              if (!a || !a.getBoundingClientRect) continue;
              if (isIgnored(a)) continue;

              var rect = a.getBoundingClientRect();
              if (rect.height < 10 || rect.width < 20) continue;
              if (rect.bottom < minTop || rect.top > maxTop) continue;

              var href = a.getAttribute('href') || a.href;
              if (!href) continue;

              // Skip junk protocols.
              var raw = (''+href).trim();
              if (raw.startsWith('javascript:') || raw.startsWith('mailto:') || raw.startsWith('tel:')) continue;

              var url = safeURL(raw);
              if (!url) continue;
              if (!(url.protocol === 'http:' || url.protocol === 'https:')) continue;

              // Skip same-page fragment jumps (usually TOC / nav noise).
              var sameDoc = (url.origin === location.origin) && (url.pathname === location.pathname);
              if (sameDoc && url.hash && url.hash.length > 1) continue;

              var text = cleanText(a.innerText || a.textContent || '');
              if (!text || text.length < 3) continue;
              if (text.length > 140) text = text.slice(0, 140);

              var sameHost = ((url.host || '').toLowerCase() === currentHost);
              var hint = sameHost ? 'Same Site' : (url.host || '');

              // Score: lower is better.
              var midY = (rect.top + rect.bottom) * 0.5;
              var dist = Math.abs(midY - centerY);

              // Reward decent, "article-like" anchor text lengths.
              var tlen = text.length;
              var textPenalty = 0;
              if (tlen < 6) textPenalty += 120;
              else if (tlen < 10) textPenalty += 40;
              else if (tlen <= 70) textPenalty -= 40;
              else textPenalty += 30;

              // Slight bias for same-host so it feels more context aware.
              var hostBias = sameHost ? -90 : 0;

              // Penalize links that are likely UI controls.
              var role = (a.getAttribute('role') || '').toLowerCase();
              var aria = cleanText(a.getAttribute('aria-label') || '');
              var uiPenalty = 0;
              if (role === 'button') uiPenalty += 120;
              if (aria && aria.length < 4) uiPenalty += 80;

              // Encourage visible links that are not tiny.
              var sizePenalty = 0;
              if (rect.height < 14) sizePenalty += 40;

              var score = dist + textPenalty + hostBias + uiPenalty + sizePenalty;

              out.push({
                title: text,
                url: url.toString(),
                hint: hint,
                score: score
              });
            }

            out.sort(function(a,b){ return a.score - b.score; });

            // Deduplicate by normalized URL.
            var uniq = [];
            var seen = {};
            for (var j=0;j<out.length && uniq.length<MAX;j++) {
              var u = (out[j].url || '').toLowerCase();
              if (!u) continue;
              if (seen[u]) continue;
              seen[u] = 1;
              uniq.push(out[j]);
            }

            return JSON.stringify(uniq);
          } catch(e) {
            return '[]';
          }
        })();
        """
      }

      public static func decode(json: String) -> [CompanionItem] {
        guard let data = json.data(using: .utf8) else { return [] }
        guard let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return [] }

        var out: [CompanionItem] = []
        out.reserveCapacity(min(arr.count, 32))

        for obj in arr {
            guard let url = obj["url"] as? String, url.isEmpty == false else { continue }
            let title = (obj["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let hint = obj["hint"] as? String
            let safeTitle: String
            if let t = title, !t.isEmpty {
              safeTitle = t
            } else {
              safeTitle = url
            }
            out.append(CompanionItem(title: safeTitle, urlString: url, hint: hint))
        }
        return out
    }
}
