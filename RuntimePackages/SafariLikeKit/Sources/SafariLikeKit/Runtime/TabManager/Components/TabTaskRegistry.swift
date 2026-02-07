import Foundation
import SafariLikeCoreKit
@MainActor
final class TabTaskRegistry {
    enum Key: Hashable {
        case ensureLoaded
        case bindActiveTab
        case renderBudgetActivate
        case splitCompanionActivate
        case scrollRestore
        case close
    }
    private var tasksByTabID: [UUID: [Key: Task<Void, Never>]] = [:]

    func hasAnyTask(tabID: UUID, keys: Set<Key>? = nil) -> Bool {
        guard let tasks = tasksByTabID[tabID] else { return false }
        if let keys {
            return tasks.keys.contains(where: { keys.contains($0) })
        }
        return tasks.isEmpty == false
    }

    func replaceTask(tabID: UUID, key: Key, _ makeTask: () -> Task<Void, Never>) {
        cancelTask(tabID: tabID, key: key)
        let task = makeTask()
        tasksByTabID[tabID, default: [:]][key] = task
    }
    func cancelTask(tabID: UUID, key: Key) {
        tasksByTabID[tabID]?[key]?.cancel()
        tasksByTabID[tabID]?[key] = nil
        if tasksByTabID[tabID]?.isEmpty == true {
            tasksByTabID[tabID] = nil
        }
    }
    func cancelAll(for tabID: UUID, excluding keysToKeep: Set<Key> = []) {
        guard let tasks = tasksByTabID[tabID] else { return }
        for (key, task) in tasks where keysToKeep.contains(key) == false {
            task.cancel()
            tasksByTabID[tabID]?[key] = nil
        }
        if tasksByTabID[tabID]?.isEmpty == true {
            tasksByTabID[tabID] = nil
        }
    }
    func cancelTasks(exceptKeepSet keepSet: Set<UUID>, keys: Set<Key>) {
        for (tabID, tasks) in tasksByTabID {
            guard keepSet.contains(tabID) == false else { continue }
            for (key, task) in tasks where keys.contains(key) {
                task.cancel()
                tasksByTabID[tabID]?[key] = nil
            }
            if tasksByTabID[tabID]?.isEmpty == true {
                tasksByTabID[tabID] = nil
            }
        }
    }
}
