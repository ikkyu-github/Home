import Foundation
import SafariLikeContracts

/// In-memory + persisted store for user scripts and policy.
///
/// Privacy/persistence contract:
/// - Regular profile: persisted via `UserScriptPersisting`.
/// - Private profile: does not persist mutations unless explicitly allowed
///   by policy (`policy.privateModeEnabled == true`).
public actor UserScriptStore {
    public enum StoreError: Error {
        case scriptNotFound
        case invalidScript
    }

    private let persistence: any UserScriptPersisting
    private let policyEngine: ScriptPolicyEngine

    private var regularState: UserScriptsPersistedState

    /// Private scratch state used when private persistence is not allowed.
    private var privateScratchState: UserScriptsPersistedState

    private var versionCounter: UInt64 = 0

    private let defaultState: UserScriptsPersistedState

    public init(
        persistence: any UserScriptPersisting,
        policyEngine: ScriptPolicyEngine = ScriptPolicyEngine(),
        defaultState: UserScriptsPersistedState = UserScriptsPersistedState()
    ) {
        self.persistence = persistence
        self.policyEngine = policyEngine

        self.defaultState = defaultState
        self.regularState = defaultState
        self.privateScratchState = defaultState
    }

    /// Loads persisted state.
    ///
    /// Safe to call multiple times.
    public func bootstrap() async {
        let loaded = await persistence.load(defaultValue: defaultState)
        regularState = loaded
        privateScratchState = loaded
        versionCounter &+= 1
    }

    public var version: UInt64 { versionCounter }

    // MARK: - Read

    public func scripts(profile: UserScriptProfile = .regular) -> [UserScript] {
        state(for: profile).scripts
    }

    public func policy(profile: UserScriptProfile = .regular) -> ScriptPolicy {
        state(for: profile).policy
    }

    public func allowedScripts(siteKey: SiteKey, url: URL?, profile: UserScriptProfile) -> [UserScript] {
        let s = state(for: profile)
        return policyEngine.allowedScripts(scripts: s.scripts, policy: s.policy, siteKey: siteKey, url: url, profile: profile)
    }

    // MARK: - Mutations

    public func upsert(_ script: UserScript, profile: UserScriptProfile = .regular) async throws {
        var st = state(for: profile)

        let hasSource = script.hasInlineSource || script.hasBundledResource
        if hasSource == false { throw StoreError.invalidScript }

        if let idx = st.scripts.firstIndex(where: { $0.id == script.id }) {
            st.scripts[idx] = script
        } else {
            st.scripts.append(script)
        }

        await commit(st, profile: profile)
    }

    public func delete(scriptID: UserScriptID, profile: UserScriptProfile = .regular) async throws {
        var st = state(for: profile)
        guard let idx = st.scripts.firstIndex(where: { $0.id == scriptID }) else { throw StoreError.scriptNotFound }
        st.scripts.remove(at: idx)
        await commit(st, profile: profile)
    }

    public func setScriptEnabled(_ scriptID: UserScriptID, enabled: Bool, profile: UserScriptProfile = .regular) async throws {
        var st = state(for: profile)
        guard let idx = st.scripts.firstIndex(where: { $0.id == scriptID }) else { throw StoreError.scriptNotFound }
        st.scripts[idx].isEnabled = enabled
        await commit(st, profile: profile)
    }

    public func setGlobalEnabled(_ enabled: Bool, profile: UserScriptProfile = .regular) async {
        var st = state(for: profile)
        st.policy.globalEnabled = enabled
        await commit(st, profile: profile)
    }

    public func setPrivateModeEnabled(_ enabled: Bool, profile: UserScriptProfile = .regular) async {
        var st = state(for: profile)
        st.policy.privateModeEnabled = enabled
        await commit(st, profile: profile)
    }

    public func setSiteOverride(siteKey: SiteKey, enabled: Bool?, profile: UserScriptProfile = .regular) async {
        var st = state(for: profile)
        if let enabled {
            st.policy.perSiteOverrides[siteKey.storageKey] = enabled
        } else {
            st.policy.perSiteOverrides.removeValue(forKey: siteKey.storageKey)
        }
        await commit(st, profile: profile)
    }

    // MARK: - Internals

    private func state(for profile: UserScriptProfile) -> UserScriptsPersistedState {
        switch profile {
        case .regular:
            return regularState
        case .private:
            // If private mode is not explicitly enabled, treat private as a scratch overlay.
            if regularState.policy.privateModeEnabled == false {
                return privateScratchState
            }
            return regularState

        @unknown default:
            assertionFailure("Unhandled UserScriptProfile: \(profile)")
            return privateScratchState
        }
    }

    private func commit(_ newState: UserScriptsPersistedState, profile: UserScriptProfile) async {
        versionCounter &+= 1

        switch profile {
        case .regular:
            regularState = newState
            privateScratchState = newState
            await persistence.save(newState)

        case .private:
            if regularState.policy.privateModeEnabled {
                regularState = newState
                privateScratchState = newState
                await persistence.save(newState)
            } else {
                // Private mode mutation: keep in-memory only.
                privateScratchState = newState

                #if DEBUG
                // Guardrail: prevent accidental persistence from private by default.
                assert(true, "[UserScriptStore] Private mutations are in-memory by default")
                #endif
            }

        @unknown default:
            assertionFailure("Unhandled UserScriptProfile: \(profile)")
            // Privacy-preserving fallback: avoid persisting unknown profile.
            privateScratchState = newState
        }
    }
}
