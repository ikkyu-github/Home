import Foundation
import SafariLikeContracts

public struct UserScriptsPersistedState: Codable, Hashable, Sendable {
    public var scripts: [UserScript]
    public var policy: ScriptPolicy

    public init(scripts: [UserScript] = [], policy: ScriptPolicy = ScriptPolicy()) {
        self.scripts = scripts
        self.policy = policy
    }
}

public protocol UserScriptPersisting: Sendable {
    func load(defaultValue: UserScriptsPersistedState) async -> UserScriptsPersistedState
    func save(_ value: UserScriptsPersistedState) async
}
