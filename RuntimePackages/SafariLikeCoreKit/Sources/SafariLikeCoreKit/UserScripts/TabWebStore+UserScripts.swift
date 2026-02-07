import Foundation
import WebKit
import SafariLikeContracts
import BrowserCore

extension TabWebStore {
        /// Applies (or refreshes) user scripts in the `WKWebViewConfiguration`.
        ///
        /// Must be called before `WKWebView.load(...)` so `documentStart` scripts are in place.
        ///
        /// Important: this intentionally does **not** call `removeAllUserScripts()` because
        /// other subsystems (e.g. resource plugins) may have installed scripts/styles into
        /// the same `WKUserContentController`.
    @MainActor
    internal func applyUserScriptsIfNeeded(for url: URL, in webView: WKWebView) async {
        WebViewPool.assertWebViewAllocatedByPool(webView)
        guard let userScriptStore else { return }
        let profile: UserScriptProfile = (browsingProfile == .private) ? .private : .regular

        let storeVersion = await userScriptStore.version
        let fingerprint = Self.userScriptsFingerprint(profile: profile, storeVersion: storeVersion)

        let ucc = webView.configuration.userContentController
        let hasRuntimeMarker = Self.hasInstalledRuntimeScripts(
            in: ucc,
            storeVersion: storeVersion,
            profile: profile
        )

        // Fast path: if this store thinks it applied the current version AND the target webView
        // actually has our runtime scripts installed, do nothing.
        if lastAppliedUserScriptsFingerprint == fingerprint, hasRuntimeMarker {
            return
        }

        // Idempotent install across WKWebView reuse: only add our scripts when the marker
        // for this version/profile is missing.
        guard hasRuntimeMarker == false else {
            lastAppliedUserScriptsFingerprint = fingerprint
            return
        }

        let policy = await userScriptStore.policy(profile: profile)
        let scripts = await userScriptStore.scripts(profile: profile)
        let payload = Self.makePayload(storeVersion: storeVersion, profile: profile, policy: policy, scripts: scripts)

        let startJS = Self.makeUserScriptsRuntimeJS(payloadBase64: payload, injectionTime: .documentStart, storeVersion: storeVersion, profile: profile)
        let endJS = Self.makeUserScriptsRuntimeJS(payloadBase64: payload, injectionTime: .documentEnd, storeVersion: storeVersion, profile: profile)

        ucc.addUserScript(
            WKUserScript(
                source: startJS,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        ucc.addUserScript(
            WKUserScript(
                source: endJS,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )

        lastAppliedUserScriptsFingerprint = fingerprint
    }

    private static func userScriptsFingerprint(
        profile: UserScriptProfile,
                storeVersion: UInt64
    ) -> UInt64 {
        var hasher = Hasher()
        hasher.combine(profile.rawValue)
        hasher.combine(storeVersion)
        return UInt64(bitPattern: Int64(hasher.finalize()))
    }

        private struct RuntimePayload: Codable, Sendable {
                struct JSScript: Codable, Sendable {
                        let id: String
                        let name: String
                        let source: String
                        let injectionTime: InjectionTime
                        let isEnabled: Bool
                        let profilesAllowed: [UserScriptProfile]
                        let matchRules: UserScriptMatchRules
                }

                let version: UInt64
                let profile: UserScriptProfile
                let policy: ScriptPolicy
                let scripts: [JSScript]
        }

        private static func makePayload(
                storeVersion: UInt64,
                profile: UserScriptProfile,
                policy: ScriptPolicy,
                scripts: [UserScript]
        ) -> String {
                let jsScripts: [RuntimePayload.JSScript] = scripts.compactMap { s in
                guard let source = resolveSource(for: s)?.trimmingCharacters(in: .whitespacesAndNewlines), !source.isEmpty else {
                    return nil
                }
                        return RuntimePayload.JSScript(
                                id: s.id.uuid.uuidString,
                                name: s.name,
                                source: source,
                                injectionTime: s.injectionTime,
                                isEnabled: s.isEnabled,
                                profilesAllowed: Array(s.profilesAllowed),
                                matchRules: s.matchRules
                        )
                }

                let payload = RuntimePayload(version: storeVersion, profile: profile, policy: policy, scripts: jsScripts)

                let encoder = JSONEncoder()
                encoder.outputFormatting = []
                let data = (try? encoder.encode(payload)) ?? Data("{}".utf8)
                return data.base64EncodedString()
        }

        private static let isDebugBuild: Bool = {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }()

        private static func runtimeMarker(storeVersion: UInt64, profile: UserScriptProfile, injectionTime: InjectionTime) -> String {
            "/*SLK_USER_SCRIPTS runtime profile=\(profile.rawValue) time=\(injectionTime.rawValue) version=\(storeVersion)*/"
        }

        private static func hasInstalledRuntimeScripts(
            in controller: WKUserContentController,
            storeVersion: UInt64,
            profile: UserScriptProfile
        ) -> Bool {
            let start = runtimeMarker(storeVersion: storeVersion, profile: profile, injectionTime: .documentStart)
            let end = runtimeMarker(storeVersion: storeVersion, profile: profile, injectionTime: .documentEnd)
            var hasStart = false
            var hasEnd = false
            for s in controller.userScripts {
                let src = s.source
                if !hasStart, src.contains(start) { hasStart = true }
                if !hasEnd, src.contains(end) { hasEnd = true }
                if hasStart, hasEnd { return true }
            }
            return false
        }

        private static func makeUserScriptsRuntimeJS(payloadBase64: String, injectionTime: InjectionTime, storeVersion: UInt64, profile: UserScriptProfile) -> String {
                // One script per injection time. We use version-gated microtasks so stale installed
                // runtime scripts (from older store versions) become no-ops without needing removal.
                let time = injectionTime.rawValue
                let marker = runtimeMarker(storeVersion: storeVersion, profile: profile, injectionTime: injectionTime)
                let debugPost = isDebugBuild ? """
                    function debugPostExec(payload) {
                        try {
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.slkUserScriptExec) {
                                window.webkit.messageHandlers.slkUserScriptExec.postMessage(payload);
                            }
                        } catch (_) {}
                    }
                """ : "function debugPostExec(_) {}"
                return """
                (function() {
                    \(marker)
                    var SLK_KEY = '__slkUserScripts';
                    var desiredKey = SLK_KEY + '.desired.' + '\(profile.rawValue)' + '.' + '\(time)';
                    var payloadKey = SLK_KEY + '.payload';
                    var logKey = SLK_KEY + '.log';

                    \(debugPost)

                    function decodeBase64Utf8(b64) {
                        var bin = atob(b64);
                        if (typeof TextDecoder !== 'undefined') {
                            var bytes = new Uint8Array(bin.length);
                            for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
                            return new TextDecoder('utf-8').decode(bytes);
                        }
                        try { return decodeURIComponent(escape(bin)); } catch (e) { return bin; }
                    }

                    function safeNow() {
                        try { return Date.now(); } catch (e) { return 0; }
                    }

                    function normHost() {
                        var h = '';
                        try { h = (window.location && window.location.hostname) ? window.location.hostname : ''; } catch (e) { h = ''; }
                        return (h || '').toLowerCase();
                    }

                    function hostMatches(pattern, host) {
                        if (!pattern) return false;
                        var p = String(pattern).trim().toLowerCase();
                        if (!p) return false;
                        if (p === '*') return true;
                        if (p.indexOf('*.') === 0) {
                            var base = p.slice(2);
                            if (!base) return false;
                            return host === base || host.endsWith('.' + base);
                        }
                        return host === p;
                    }

                    function matchesAnyHost(patterns, host) {
                        if (!patterns || !patterns.length) return false;
                        for (var i = 0; i < patterns.length; i++) {
                            if (hostMatches(patterns[i], host)) return true;
                        }
                        return false;
                    }

                    function globMatches(pattern, value) {
                        if (!pattern) return false;
                        var p = String(pattern).trim();
                        if (!p) return false;
                        if (p === '*') return true;
                        var parts = p.split('*');
                        if (parts.length === 1) return value === p;

                        var index = 0;
                        if (parts[0] && p[0] !== '*') {
                            if (value.indexOf(parts[0]) !== 0) return false;
                            index = parts[0].length;
                        }

                        for (var j = 1; j < parts.length - 1; j++) {
                            var part = parts[j];
                            if (!part) continue;
                            var foundAt = value.indexOf(part, index);
                            if (foundAt < 0) return false;
                            index = foundAt + part.length;
                        }

                        var last = parts[parts.length - 1];
                        if (last && p[p.length - 1] !== '*') {
                            return value.lastIndexOf(last) === (value.length - last.length);
                        }
                        return true;
                    }

                    function matchesAnyGlob(patterns, value) {
                        if (!patterns || !patterns.length) return false;
                        for (var i = 0; i < patterns.length; i++) {
                            if (globMatches(patterns[i], value)) return true;
                        }
                        return false;
                    }

                    function scriptAllowed(script, payload, host, href) {
                        if (!payload || !payload.policy || !script) return false;
                        var policy = payload.policy;
                        if (policy.globalEnabled !== true) return false;
                        if (payload.profile === 'private' && policy.privateModeEnabled !== true) return false;
                        if (policy.perSiteOverrides && policy.perSiteOverrides[host] === false) return false;
                        if (script.isEnabled !== true) return false;
                        if (script.profilesAllowed && script.profilesAllowed.length) {
                            var okProfile = false;
                            for (var i = 0; i < script.profilesAllowed.length; i++) {
                                if (script.profilesAllowed[i] === payload.profile) { okProfile = true; break; }
                            }
                            if (!okProfile) return false;
                        }

                        var rules = script.matchRules || {};
                        if (matchesAnyHost(rules.excludeHosts, host)) return false;
                        if (rules.includeHosts && rules.includeHosts.length) {
                            if (!matchesAnyHost(rules.includeHosts, host)) return false;
                        }
                        if (matchesAnyGlob(rules.excludeURLPatterns, href)) return false;
                        if (rules.includeURLPatterns && rules.includeURLPatterns.length) {
                            if (!matchesAnyGlob(rules.includeURLPatterns, href)) return false;
                        }
                        return true;
                    }

                    function sortScripts(a, b) {
                        // InjectionTime is handled by the caller; keep name + id stable.
                        var an = (a.name || '').toLowerCase();
                        var bn = (b.name || '').toLowerCase();
                        if (an < bn) return -1;
                        if (an > bn) return 1;
                        var ai = (a.id || '');
                        var bi = (b.id || '');
                        if (ai < bi) return -1;
                        if (ai > bi) return 1;
                        return 0;
                    }

                    var payloadText = decodeBase64Utf8('\(payloadBase64)');
                    var payload;
                    try { payload = JSON.parse(payloadText); } catch (e) { payload = null; }
                    if (!payload || typeof payload.version !== 'number') return;

                    var currentDesired = window[desiredKey] || 0;
                    if (payload.version > currentDesired) window[desiredKey] = payload.version;

                    queueMicrotask(function() {
                        if ((window[desiredKey] || 0) !== payload.version) return;
                        window[payloadKey] = payload;

                        var host = normHost();
                        var href = '';
                        try { href = (window.location && window.location.href) ? String(window.location.href) : ''; } catch (e) { href = ''; }

                        var scripts = (payload.scripts || []).filter(function(s) {
                            return s && s.injectionTime === '\(time)';
                        });
                        scripts.sort(sortScripts);

                        for (var i = 0; i < scripts.length; i++) {
                            var s = scripts[i];
                            if (!scriptAllowed(s, payload, host, href)) continue;
                            try {
                                (0, eval)(String(s.source || ''));
                                if (!window[logKey]) window[logKey] = [];
                                window[logKey].push({ t: safeNow(), id: s.id, time: '\(time)', ok: true });
                                debugPostExec({ t: safeNow(), id: s.id, time: '\(time)', ok: true });
                            } catch (e) {
                                if (!window[logKey]) window[logKey] = [];
                                window[logKey].push({ t: safeNow(), id: s.id, time: '\(time)', ok: false, err: String(e && e.message ? e.message : e) });
                                debugPostExec({ t: safeNow(), id: s.id, time: '\(time)', ok: false, err: String(e && e.message ? e.message : e) });
                            }
                        }
                    });
                })();
                """
        }

        private static func resolveSource(for script: UserScript) -> String? {
            if let s = script.sourceCode, s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                return s
            }
            if let name = script.bundledResourceName?.trimmingCharacters(in: .whitespacesAndNewlines), name.isEmpty == false {
                return loadBundledUserScriptSource(named: name)
            }
            return nil
        }

        private static func loadBundledUserScriptSource(named rawName: String) -> String? {
            let maxBytes = 200 * 1024
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.isEmpty == false else { return nil }

            func load(from bundle: Bundle) -> String? {
                let url: URL?
                if name.contains(".") {
                    url = bundle.url(forResource: name, withExtension: nil)
                } else {
                    url = bundle.url(forResource: name, withExtension: "js") ?? bundle.url(forResource: name, withExtension: nil)
                }
                guard let url else { return nil }
                guard let data = try? Data(contentsOf: url) else { return nil }
                guard data.count <= maxBytes else { return nil }
                return String(data: data, encoding: .utf8)
            }

            // Prefer SPM resources when available.
            #if SWIFT_PACKAGE
            if let s = load(from: .module) { return s }
            #endif
            // Fallback for app-bundled resources.
            if let s = load(from: .main) { return s }
            return nil
        }
}
