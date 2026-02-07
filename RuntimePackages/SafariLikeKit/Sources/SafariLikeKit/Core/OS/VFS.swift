import Foundation
import SafariLikeCoreKit
// MARK: - Virtual Filesystem (VFS)
//
// Phase 1 goal: Provide a predictable file API for "apps" that does NOT directly expose the real sandbox.
// This is intentionally small and boring: directories + files + permissions hooks.
// Persistence: a simple on-disk JSON store under Application Support.
//
// You can swap the backing store later (CoreData, SQLite, CloudKit, etc).
enum VFSItemType: String, Codable {
    case file
    case directory
}
struct VFSMetadata: Codable, Equatable {
    var createdAt: Date
    var modifiedAt: Date
    var type: VFSItemType
    var size: Int
    init(createdAt: Date = Date(), modifiedAt: Date = Date(), type: VFSItemType, size: Int = 0) {
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.type = type
        self.size = size
    }
}
enum VFSError: Error, LocalizedError {
    case invalidPath(String)
    case notFound(String)
    case notDirectory(String)
    case notFile(String)
    case alreadyExists(String)
    case permissionDenied(String)
    case corruptStore(String)
    var errorDescription: String? {
        switch self {
        case .invalidPath(let p): return "Invalid path: \(p)"
        case .notFound(let p): return "Not found: \(p)"
        case .notDirectory(let p): return "Not a directory: \(p)"
        case .notFile(let p): return "Not a file: \(p)"
        case .alreadyExists(let p): return "Already exists: \(p)"
        case .permissionDenied(let p): return "Permission denied: \(p)"
        case .corruptStore(let msg): return "Corrupt VFS store: \(msg)"
        @unknown default:
            return nil
        }
    }
}
// MARK: - In-memory tree
final class VFSNode: Codable {
    let name: String
    var meta: VFSMetadata
    // Directory-only
    var children: [String: VFSNode]?
    // File-only
    var dataBase64: String?
    init(name: String, meta: VFSMetadata, children: [String: VFSNode]? = nil, dataBase64: String? = nil) {
        self.name = name
        self.meta = meta
        self.children = children
        self.dataBase64 = dataBase64
    }
    var isDirectory: Bool { meta.type == .directory }
    var isFile: Bool { meta.type == .file }
}
protocol VFSAccessPolicy {
    /// Decide if a caller is allowed to access a path.
    /// Keep it simple for now; Phase 2 will make this permission-driven.
    func canAccess(callerID: String, path: String, write: Bool) -> Bool
}
struct AllowAllVFSAccessPolicy: VFSAccessPolicy {
    init() {}
    func canAccess(callerID: String, path: String, write: Bool) -> Bool { true }
}
// MARK: - Persistent store
protocol VFSBackingStore {
    func load(rootKey: String) throws -> VFSNode?
    func save(rootKey: String, root: VFSNode) throws
}
final class DiskJSONVFSStore: VFSBackingStore {
    private let directoryURL: URL
    init(appGroupID: String? = nil, folderName: String = "VFSStore") {
        // Prefer App Group if provided, else Application Support.
        let base: URL = {
            if let appGroupID,
               let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
                return groupURL
            }
            // Application Support should exist, but it can be temporarily unavailable in some edge cases.
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                return appSupport
            }
            // Fallbacks: Documents -> temporary directory.
            if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                return docs
            }
            return FileManager.default.temporaryDirectory
        }()
        directoryURL = base.appendingPathComponent(folderName, isDirectory: true)
        // ✅ Correct API (attributes parameter) + best-effort folder creation.
        try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    func load(rootKey: String) throws -> VFSNode? {
        let url = directoryURL.appendingPathComponent("\(rootKey).json", isDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode(VFSNode.self, from: data)
        } catch {
            throw VFSError.corruptStore("Decode failed for \(rootKey): \(error.localizedDescription)")
        }
    }
    func save(rootKey: String, root: VFSNode) throws {
        let url = directoryURL.appendingPathComponent("\(rootKey).json", isDirectory: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(root)
        try data.write(to: url, options: [.atomic])
    }
}
// MARK: - VFS main API
// INTERNAL ONLY - Not part of public API
final class VirtualFileSystem {
    struct Namespace: Hashable {
        let key: String
        init(_ key: String) { self.key = key }
    }
    private let store: VFSBackingStore
    private let access: VFSAccessPolicy
    private var roots: [Namespace: VFSNode] = [:]
    private let lock = NSLock()
    init(store: VFSBackingStore = DiskJSONVFSStore(),
                access: VFSAccessPolicy = AllowAllVFSAccessPolicy()) {
        self.store = store
        self.access = access
    }
    // Create or load the root for a namespace (e.g. per-app sandbox)
    func open(namespace: Namespace) throws {
        lock.lock(); defer { lock.unlock() }
        if roots[namespace] != nil { return }
        if let loaded = try store.load(rootKey: namespace.key) {
            roots[namespace] = loaded
        } else {
            // Default layout
            let root = VFSNode(
                name: "/",
                meta: .init(type: .directory),
                children: [
                    "system": VFSNode(name: "system", meta: .init(type: .directory), children: [:]),
                    "apps": VFSNode(name: "apps", meta: .init(type: .directory), children: [:]),
                    "user": VFSNode(name: "user", meta: .init(type: .directory), children: [:]),
                    "tmp": VFSNode(name: "tmp", meta: .init(type: .directory), children: [:]),
                ]
            )
            roots[namespace] = root
            try store.save(rootKey: namespace.key, root: root)
        }
    }
    func flush(namespace: Namespace) throws {
        lock.lock(); defer { lock.unlock() }
        guard let root = roots[namespace] else { return }
        try store.save(rootKey: namespace.key, root: root)
    }
    // MARK: Path helpers
    private func normalize(_ path: String) throws -> [String] {
        guard path.hasPrefix("/") else { throw VFSError.invalidPath(path) }
        let parts = path.split(separator: "/").map(String.init).filter { !$0.isEmpty && $0 != "." }
        var stack: [String] = []
        for p in parts {
            if p == ".." {
                if !stack.isEmpty { _ = stack.removeLast() }
            } else {
                stack.append(p)
            }
        }
        return stack
    }
    private func requireAccess(callerID: String, path: String, write: Bool) throws {
        if !access.canAccess(callerID: callerID, path: path, write: write) {
            throw VFSError.permissionDenied(path)
        }
    }
    private func resolve(namespace: Namespace, path: String) throws -> (parent: VFSNode?, node: VFSNode?, name: String) {
        let parts = try normalize(path)
        guard let root = roots[namespace] else { throw VFSError.notFound("namespace \(namespace.key) not opened") }
        if parts.isEmpty { return (nil, root, "/") }
        var current = root
        var parent: VFSNode? = nil
        for (idx, part) in parts.enumerated() {
            guard current.isDirectory else { throw VFSError.notDirectory("/" + parts.prefix(idx).joined(separator: "/")) }
            let next = current.children?[part]
            parent = current
            current = next ?? VFSNode(name: part, meta: .init(type: .directory), children: nil) // placeholder
            if next == nil { return (parent, nil, part) }
        }
        guard let last = parts.last else { throw VFSError.invalidPath(path) }
        return (parent, current, last)
    }
    private func getNode(namespace: Namespace, path: String) throws -> VFSNode {
        let parts = try normalize(path)
        guard let root = roots[namespace] else { throw VFSError.notFound("namespace \(namespace.key) not opened") }
        if parts.isEmpty { return root }
        var current = root
        for (idx, part) in parts.enumerated() {
            guard current.isDirectory else { throw VFSError.notDirectory("/" + parts.prefix(idx).joined(separator: "/")) }
            guard let next = current.children?[part] else { throw VFSError.notFound(path) }
            current = next
        }
        return current
    }
    // MARK: - Internal operations
    func list(callerID: String, namespace: Namespace, path: String) throws -> [String] {
        try requireAccess(callerID: callerID, path: path, write: false)
        lock.lock(); defer { lock.unlock() }
        let node = try getNode(namespace: namespace, path: path)
        guard node.isDirectory else { throw VFSError.notDirectory(path) }
        return node.children?.keys.sorted() ?? []
    }
    func mkdir(callerID: String, namespace: Namespace, path: String) throws {
        try requireAccess(callerID: callerID, path: path, write: true)
        lock.lock(); defer { lock.unlock() }
        let parts = try normalize(path)
        guard let root = roots[namespace] else { throw VFSError.notFound("namespace \(namespace.key) not opened") }
        if parts.isEmpty { return }
        var current = root
        for part in parts {
            guard current.isDirectory else { throw VFSError.notDirectory(path) }
            if current.children == nil { current.children = [:] }
            if let existing = current.children?[part] {
                current = existing
            } else {
                let newDir = VFSNode(name: part, meta: .init(type: .directory), children: [:])
                current.children?[part] = newDir
                current.meta.modifiedAt = Date()
                current = newDir
            }
        }
    }
    func writeFile(callerID: String, namespace: Namespace, path: String, data: Data, createParents: Bool = true) throws {
        try requireAccess(callerID: callerID, path: path, write: true)
        lock.lock(); defer { lock.unlock() }
        let parts = try normalize(path)
        guard !parts.isEmpty else { throw VFSError.invalidPath(path) }
        guard let root = roots[namespace] else { throw VFSError.notFound("namespace \(namespace.key) not opened") }
        let dirParts = parts.dropLast()
        guard let fileName = parts.last else { throw VFSError.invalidPath(path) }
        var current = root
        for part in dirParts {
            guard current.isDirectory else { throw VFSError.notDirectory("/" + dirParts.joined(separator: "/")) }
            if current.children == nil { current.children = [:] }
            if let existing = current.children?[part] {
                current = existing
            } else if createParents {
                let newDir = VFSNode(name: part, meta: .init(type: .directory), children: [:])
                current.children?[part] = newDir
                current = newDir
            } else {
                throw VFSError.notFound("/" + dirParts.joined(separator: "/"))
            }
        }
        if current.children == nil { current.children = [:] }
        let fileNode = VFSNode(
            name: fileName,
            meta: .init(type: .file, size: data.count),
            children: nil,
            dataBase64: data.base64EncodedString()
        )
        fileNode.meta.modifiedAt = Date()
        current.children?[fileName] = fileNode
        current.meta.modifiedAt = Date()
    }
    func readFile(callerID: String, namespace: Namespace, path: String) throws -> Data {
        try requireAccess(callerID: callerID, path: path, write: false)
        lock.lock(); defer { lock.unlock() }
        let node = try getNode(namespace: namespace, path: path)
        guard node.isFile else { throw VFSError.notFile(path) }
        guard let b64 = node.dataBase64, let data = Data(base64Encoded: b64) else {
            throw VFSError.corruptStore("File payload missing for \(path)")
        }
        return data
    }
    func delete(callerID: String, namespace: Namespace, path: String) throws {
        try requireAccess(callerID: callerID, path: path, write: true)
        lock.lock(); defer { lock.unlock() }
        let parts = try normalize(path)
        guard !parts.isEmpty else { throw VFSError.invalidPath(path) }
        guard let root = roots[namespace] else { throw VFSError.notFound("namespace \(namespace.key) not opened") }
        var current = root
        for (idx, part) in parts.dropLast().enumerated() {
            guard current.isDirectory else { throw VFSError.notDirectory("/" + parts.prefix(idx).joined(separator: "/")) }
            guard let next = current.children?[part] else { throw VFSError.notFound(path) }
            current = next
        }
        guard let name = parts.last else { throw VFSError.invalidPath(path) }
        guard current.children?[name] != nil else { throw VFSError.notFound(path) }
        current.children?.removeValue(forKey: name)
        current.meta.modifiedAt = Date()
    }
}
