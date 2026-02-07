import Foundation
import SafariLikeCoreKit
// MARK: - Virtual Process Model
//
// This is a "process" in the webOS sense: an app runtime unit you can start/kill/suspend,
// even though everything is in one iOS process underneath.
// Phase 1 keeps it simple (no permission enforcement, no real isolation).
// Phase 2 will wire permissions + service auth.
enum OSProcessState: String, Codable {
    case running
    case suspended
    case terminated
}
struct OSProcessSnapshot: Codable, Equatable {
    var pid: Int
    var bundleID: String
    var state: OSProcessState
    var lastActiveAt: Date
    var userInfo: [String: String]?
    init(pid: Int, bundleID: String, state: OSProcessState, lastActiveAt: Date, userInfo: [String: String]? = nil) {
        self.pid = pid
        self.bundleID = bundleID
        self.state = state
        self.lastActiveAt = lastActiveAt
        self.userInfo = userInfo
    }
}
final class OSProcess: Codable {
    let pid: Int
    let bundleID: String
    let displayName: String
    var permissions: Set<String>
    var memoryQuotaMB: Int
    var createdAt: Date
    var lastActiveAt: Date
    var state: OSProcessState
    // Runtime-only, not persisted
    var messageEndpoint: String? = nil
    init(pid: Int,
                bundleID: String,
                displayName: String,
                permissions: Set<String> = [],
                memoryQuotaMB: Int = 64,
                createdAt: Date = Date(),
                lastActiveAt: Date = Date(),
                state: OSProcessState = .running) {
        self.pid = pid
        self.bundleID = bundleID
        self.displayName = displayName
        self.permissions = permissions
        self.memoryQuotaMB = memoryQuotaMB
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
        self.state = state
    }
    func touch() {
        lastActiveAt = Date()
    }
    func snapshot(userInfo: [String: String]? = nil) -> OSProcessSnapshot {
        OSProcessSnapshot(pid: pid, bundleID: bundleID, state: state, lastActiveAt: lastActiveAt, userInfo: userInfo)
    }
}
