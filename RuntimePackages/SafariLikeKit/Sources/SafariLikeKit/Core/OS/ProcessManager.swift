import Foundation
import SafariLikeCoreKit
// MARK: - Process Manager (Phase 1)
//
// Responsibilities:
// - issue PIDs
// - keep process table
// - manage suspend/resume/terminate
// - optional: bind a per-process VFS namespace
//
// This is the scaffold that lets you build window-manager + cards UI later.
// INTERNAL ONLY - Not part of public API
final class ProcessManager {
    /// SAFE SINGLETON:
    /// - Process-wide OS-like scaffold used for internal prototypes.
    /// - Must not store per-window/scene/tab UI state.
    static let shared = ProcessManager()
    struct Events {
        static let processStarted = BrowserContracts.Notification.processStarted
        static let processStateChanged = BrowserContracts.Notification.processStateChanged
        static let processTerminated = BrowserContracts.Notification.processTerminated
    }
    private let lock = NSLock()
    private var nextPID: Int = 100
    private var table: [Int: OSProcess] = [:]
    let vfs: VirtualFileSystem
    private init(vfs: VirtualFileSystem = VirtualFileSystem()) {
        self.vfs = vfs
        // Example system services
        ServiceBus.shared.register("system.ping") { req in
            .success(["pong": true, "caller": req.callerBundleID])
        }
    }
    // MARK: - Internal API
    @discardableResult
    func start(bundleID: String,
                      displayName: String,
                      permissions: Set<String> = [],
                      memoryQuotaMB: Int = 64) throws -> OSProcess {
        lock.lock()
        let pid = nextPID
        nextPID += 1
        let proc = OSProcess(pid: pid,
                             bundleID: bundleID,
                             displayName: displayName,
                             permissions: permissions,
                             memoryQuotaMB: memoryQuotaMB,
                             state: .running)
        table[pid] = proc
        lock.unlock()
        // Attach per-process filesystem namespace
        try vfs.open(namespace: .init(bundleID))
        NotificationCenter.default.post(name: Events.processStarted, object: self, userInfo: [
            "pid": pid,
            "bundleID": bundleID
        ])
        return proc
    }
    func list() -> [OSProcess] {
        lock.lock(); defer { lock.unlock() }
        return table.values.sorted(by: { $0.pid < $1.pid })
    }
    func get(pid: Int) -> OSProcess? {
        lock.lock(); defer { lock.unlock() }
        return table[pid]
    }
    func touch(pid: Int) {
        lock.lock()
        let proc = table[pid]
        lock.unlock()
        proc?.touch()
    }
    func suspend(pid: Int) {
        setState(pid: pid, state: .suspended)
    }
    func resume(pid: Int) {
        setState(pid: pid, state: .running)
    }
    func terminate(pid: Int) {
        lock.lock()
        guard let proc = table.removeValue(forKey: pid) else { lock.unlock(); return }
        lock.unlock()
        proc.state = .terminated
        NotificationCenter.default.post(name: Events.processTerminated, object: self, userInfo: [
            "pid": pid,
            "bundleID": proc.bundleID
        ])
    }
    // MARK: - VFS helpers
    func vfsWriteText(pid: Int, path: String, text: String) throws {
        guard let proc = get(pid: pid) else { return }
        let ns = VirtualFileSystem.Namespace(proc.bundleID)
        try vfs.writeFile(callerID: proc.bundleID, namespace: ns, path: path, data: Data(text.utf8))
        try vfs.flush(namespace: ns)
    }
    func vfsReadText(pid: Int, path: String) throws -> String {
        guard let proc = get(pid: pid) else { throw VFSError.notFound("pid \(pid)") }
        let ns = VirtualFileSystem.Namespace(proc.bundleID)
        let data = try vfs.readFile(callerID: proc.bundleID, namespace: ns, path: path)
        return String(decoding: data, as: UTF8.self)
    }
    // MARK: - Private
    private func setState(pid: Int, state: OSProcessState) {
        lock.lock()
        guard let proc = table[pid] else { lock.unlock(); return }
        proc.state = state
        proc.touch()
        lock.unlock()
        NotificationCenter.default.post(name: Events.processStateChanged, object: self, userInfo: [
            "pid": pid,
            "bundleID": proc.bundleID,
            "state": state.rawValue
        ])
    }
}
