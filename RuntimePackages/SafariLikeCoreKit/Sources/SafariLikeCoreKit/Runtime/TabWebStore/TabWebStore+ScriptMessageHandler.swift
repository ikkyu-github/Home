import WebKit
import SafariLikeContracts
import BrowserCore

extension TabWebStore: WKScriptMessageHandler {
    /// Threading: Called by WebKit on the main actor.
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "webInputFocused":
            onWebInputFocused?()
        case "slkDOMInteractive":
            // Best-effort, passive: notify the central engine for instrumentation.
            EngineController.shared.notifyWebViewInteractive(tabID: tabID)
        case "slkLoginFormDetected":
            handleWebFormDetected(kind: .login)
        case "slkSignupFormDetected":
            handleWebFormDetected(kind: .signup)
        default:
            return
        }
    }
}

extension TabWebStore {
    internal enum WebFormEventKind {
        case login
        case signup
    }

    /// Privacy contract: do not capture form field values, and do not persist site-specific hints.
    internal func handleWebFormDetected(kind: WebFormEventKind) {
        // Strict: never run helper instrumentation for private mode.
        guard browsingProfile == .regular else { return }

        guard let url = currentURL, let host = url.host else { return }
        let siteKey = SiteKey(host: host)
        if let formFillPolicyEngine {
            let policy = formFillPolicyEngine.effectivePolicy(siteKey: siteKey, profile: WebsiteDataProfile.regular)
            guard policy.allowAutofill else { return }
        }

        switch kind {
        case .login:
            CoreKitMetrics.recordLoginFormDetected()
        case .signup:
            CoreKitMetrics.recordSignupFormDetected()
        }
    }
}

extension TabWebStore {
    internal func installUserScriptsAndMessageHandlers(into userContentController: WKUserContentController) {
        // Idempotent install: avoid duplicate handlers and user scripts.
        // Do NOT removeAllUserScripts() here; plugins may also install scripts.
        userContentController.removeScriptMessageHandler(forName: "webInputFocused")
        userContentController.add(self, name: "webInputFocused")

        userContentController.removeScriptMessageHandler(forName: "slkDOMInteractive")
        userContentController.add(self, name: "slkDOMInteractive")

        // MARK: - Autofill helper (best-effort, no secrets)
        // Strict: do not install helper observers in private mode.
        userContentController.removeScriptMessageHandler(forName: "slkLoginFormDetected")
        userContentController.removeScriptMessageHandler(forName: "slkSignupFormDetected")
        if browsingProfile == .regular {
            userContentController.add(self, name: "slkLoginFormDetected")
            userContentController.add(self, name: "slkSignupFormDetected")
        }

        let hasUserScriptContaining: (String) -> Bool = { token in
            userContentController.userScripts.contains(where: { $0.source.contains(token) })
        }

        let focusScriptSource = """
        (function() {
            function isEditable(el) {
                if (!el) return false;
                if (el.isContentEditable) return true;
                var tag = (el.tagName || '').toLowerCase();
                if (tag === 'textarea') return true;
                if (tag !== 'input') return false;
                var type = (el.getAttribute('type') || 'text').toLowerCase();
                return !['button','submit','reset','checkbox','radio','range','color','file','image','hidden'].includes(type);
            }
            document.addEventListener('focusin', function(e) {
                try {
                    if (isEditable(e.target)) {
                        window.webkit?.messageHandlers?.webInputFocused?.postMessage(1);
                    }
                } catch (_) {}
            }, true);
        })();
        """

        let script = WKUserScript(
            source: focusScriptSource,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        if !hasUserScriptContaining("webInputFocused") {
            userContentController.addUserScript(script)
        }

        // Lightweight interactive probe: report when the main document reaches at least
        // `interactive` readyState. This is used for performance tracing; it must be fast.
        let interactiveProbeSource = """
        (function() {
            function report() {
                try { window.webkit?.messageHandlers?.slkDOMInteractive?.postMessage(1); } catch (_) {}
            }
            try {
                if (document.readyState === 'interactive' || document.readyState === 'complete') {
                    report();
                    return;
                }
                document.addEventListener('DOMContentLoaded', report, { once: true, capture: true });
            } catch (_) {}
        })();
        """

        let interactiveScript = WKUserScript(
            source: interactiveProbeSource,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        if !hasUserScriptContaining("slkDOMInteractive") {
            userContentController.addUserScript(interactiveScript)
        }

                // Minimal login/signup form probe.
                // - No field values are read.
                // - No domains are sent from JS; CoreKit maps events to the current tab state.
                // - Best-effort only; used for DEBUG diagnostics and UX assistance.
                if browsingProfile == .regular, !hasUserScriptContaining("slkLoginFormDetected") {
                        let formProbeSource = """
                        (function() {
                            function scanAndReport() {
                                try {
                                    var inputs = document.querySelectorAll('input[type="password"]');
                                    if (!inputs || inputs.length === 0) return;

                                    var hasNewPassword = false;
                                    for (var i = 0; i < inputs.length; i++) {
                                        var ac = (inputs[i].getAttribute('autocomplete') || '').toLowerCase();
                                        if (ac === 'new-password') { hasNewPassword = true; break; }
                                    }

                                    window.webkit?.messageHandlers?.slkLoginFormDetected?.postMessage(1);
                                    if (hasNewPassword || inputs.length >= 2) {
                                        window.webkit?.messageHandlers?.slkSignupFormDetected?.postMessage(1);
                                    }
                                } catch (_) {}
                            }

                            try {
                                if (document.readyState === 'interactive' || document.readyState === 'complete') {
                                    setTimeout(scanAndReport, 0);
                                    return;
                                }
                                document.addEventListener('DOMContentLoaded', function() {
                                    setTimeout(scanAndReport, 0);
                                }, { once: true, capture: true });
                            } catch (_) {}
                        })();
                        """

                        let probeScript = WKUserScript(
                                source: formProbeSource,
                                injectionTime: .atDocumentEnd,
                                forMainFrameOnly: true
                        )
                        userContentController.addUserScript(probeScript)
                }
    }
}
