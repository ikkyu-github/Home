import Foundation
import os

@MainActor
final class BrowserSceneSessionRegistry {
    /// Scene/app-owned registry.
    ///
    /// Do not use a process-wide singleton here: sessions are window/scene-scoped and must not
    /// leak across scenes in multi-window.
    init() {}

    private struct Entry {
        weak var session: BrowserSceneSession?
        var sceneID: String
        var createdAt: Date
        var createdFrom: String
    }

    private let logger = Logger(subsystem: "SafariLikeKit", category: "BrowserSceneSessionRegistry")
    private var sessionsByWindowID: [UUID: Entry] = [:]

    func session(windowID: UUID) -> BrowserSceneSession? {
        guard let entry = sessionsByWindowID[windowID] else { return nil }
        guard let session = entry.session else {
            sessionsByWindowID.removeValue(forKey: windowID)
            return nil
        }
        return session
    }

    func session(windowID: UUID, sceneID: String) -> BrowserSceneSession? {
        guard var entry = sessionsByWindowID[windowID] else { return nil }
        guard let session = entry.session else {
            sessionsByWindowID.removeValue(forKey: windowID)
            return nil
        }

        if entry.sceneID != sceneID {
#if DEBUG
            logger.warning("SceneID mismatch for windowID=\(windowID, privacy: .public): existing=\(entry.sceneID, privacy: .public) requested=\(sceneID, privacy: .public)")
#endif
            entry.sceneID = sceneID
            sessionsByWindowID[windowID] = entry
        }

        return session
    }

    func getOrCreate(
        windowID: UUID,
        sceneID: String,
        create: () -> BrowserSceneSession,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) -> BrowserSceneSession {
        if let existing = session(windowID: windowID, sceneID: sceneID) {
            return existing
        }

        let created = create()
        return register(
            created,
            windowID: windowID,
            sceneID: sceneID,
            createdFrom: "\(fileID):\(line)"
        )
    }

    func register(
        _ newSession: BrowserSceneSession,
        windowID: UUID,
        sceneID: String,
        createdFrom: String
    ) -> BrowserSceneSession {
        if let existing = session(windowID: windowID, sceneID: sceneID), existing !== newSession {
#if DEBUG
            logger.warning("Duplicate BrowserSceneSession creation ignored windowID=\(windowID, privacy: .public) sceneID=\(sceneID, privacy: .public) createdFrom=\(createdFrom, privacy: .public)")
#endif
            return existing
        }

        sessionsByWindowID[windowID] = Entry(
            session: newSession,
            sceneID: sceneID,
            createdAt: Date(),
            createdFrom: createdFrom
        )
        return newSession
    }

    func remove(windowID: UUID) -> BrowserSceneSession? {
        let removed = sessionsByWindowID.removeValue(forKey: windowID)
        return removed?.session
    }
}
