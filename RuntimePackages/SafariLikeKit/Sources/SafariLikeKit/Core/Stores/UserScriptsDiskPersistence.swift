import Foundation
import SafariLikeContracts
import SafariLikeCoreKit

final class UserScriptsDiskPersistence: UserScriptPersisting {
    private let store: JSONFileStoreActor
    private let filename: String

    init(filename: String = "user_scripts.json") {
        self.store = JSONFileStoreActor()
        self.filename = filename
    }

    func load(defaultValue: UserScriptsPersistedState) async -> UserScriptsPersistedState {
        await store.load(filename: filename, defaultValue: defaultValue)
    }

    func save(_ value: UserScriptsPersistedState) async {
        await store.save(filename: filename, value: value)
    }
}
