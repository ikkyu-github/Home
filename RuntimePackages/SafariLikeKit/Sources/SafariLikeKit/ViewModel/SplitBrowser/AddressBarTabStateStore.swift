import Foundation
import SafariLikeUXKit

@MainActor
final class AddressBarTabStateStore {
    typealias Snapshot = SafariLikeUXKit.AddressBarUIStateMachine.Snapshot

    private var byTabID: [UUID: Snapshot] = [:]

    func save(tabID: UUID, snapshot: Snapshot) {
        byTabID[tabID] = snapshot
    }

    func snapshot(for tabID: UUID) -> Snapshot? {
        byTabID[tabID]
    }

    func remove(tabID: UUID) {
        byTabID.removeValue(forKey: tabID)
    }

    func removeAll() {
        byTabID.removeAll()
    }
}
