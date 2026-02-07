import Foundation
import Combine
import SafariLikeCoreKit

@MainActor
final class TabSessionSyncController {
    private unowned let manager: TabManager

    init(manager: TabManager) {
        self.manager = manager
    }

    func installSessionSubscriptions() {
        manager.sessionCancellables.removeAll()

        manager.currentSessionStore.$tabs
            .receive(on: RunLoop.main)
            .sink { [weak manager] tabs in
                guard let manager else { return }

                let previousByID = Dictionary(uniqueKeysWithValues: manager.tabs.map { ($0.id, $0) })
                manager.tabs = tabs.map { browserTab in
                    var mapped = TabState(browserTab: browserTab, isPrivate: manager.isPrivateMode)

                    if let previous = previousByID[mapped.id] {
                        mapped.hasSnapshot = previous.hasSnapshot
                        mapped.lastSnapshotAt = previous.lastSnapshotAt
                        mapped.snapshotData = previous.snapshotData
                        mapped.lifecycle = previous.lifecycle
                        mapped.runtimeAttachment = previous.runtimeAttachment
                        mapped.renderMode = previous.renderMode
                        mapped.paneID = previous.paneID
                        mapped.reader = previous.reader
                    }

                    if previousByID[mapped.id] == nil {
                        if let assigned = manager.tabPaneAssignments[mapped.id] {
                            mapped.paneID = assigned
                        } else if manager.isSplitViewEnabled, manager.rightTabID == mapped.id {
                            mapped.paneID = .secondary
                        } else {
                            mapped.paneID = .primary
                        }
                    }

                    return mapped
                }
            }
            .store(in: &manager.sessionCancellables)

        manager.currentSessionStore.$selectedTabID
            .removeDuplicates { $0 == $1 }
            .receive(on: RunLoop.main)
            .sink { [weak manager] selected in
                guard let manager else { return }
                if manager.activeTabID != selected {
                    manager.activeTabID = selected
                }
            }
            .store(in: &manager.sessionCancellables)
    }
}
