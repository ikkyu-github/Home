import Foundation
import Combine
import SafariLikeCoreKit
import SafariLikeContracts

final class UserScriptsManagerViewModel: ObservableObject {
    let store: UserScriptStore
    let isPrivateMode: Bool

    var profile: UserScriptProfile { isPrivateMode ? .private : .regular }

    @Published var policy: ScriptPolicy = ScriptPolicy()
    @Published var scripts: [UserScript] = []
    @Published var isLoaded: Bool = false

    init(store: UserScriptStore, isPrivateMode: Bool) {
        self.store = store
        self.isPrivateMode = isPrivateMode
    }

    @MainActor
    func reload() async {
        policy = await store.policy(profile: profile)
        scripts = await store.scripts(profile: profile).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        isLoaded = true
    }

    @MainActor
    func setGlobalEnabled(_ enabled: Bool) async {
        await store.setGlobalEnabled(enabled, profile: profile)
        await reload()
    }

    @MainActor
    func setPrivateModeEnabled(_ enabled: Bool) async {
        await store.setPrivateModeEnabled(enabled, profile: profile)
        await reload()
    }

    @MainActor
    func setScriptEnabled(_ id: UserScriptID, enabled: Bool) async {
        do {
            try await store.setScriptEnabled(id, enabled: enabled, profile: profile)
            await reload()
        } catch {
            await reload()
        }
    }

    @MainActor
    func upsert(_ script: UserScript) async throws {
        try await store.upsert(script, profile: profile)
        await reload()
    }

    @MainActor
    func delete(_ id: UserScriptID) async {
        do {
            try await store.delete(scriptID: id, profile: profile)
            await reload()
        } catch {
            await reload()
        }
    }
}
