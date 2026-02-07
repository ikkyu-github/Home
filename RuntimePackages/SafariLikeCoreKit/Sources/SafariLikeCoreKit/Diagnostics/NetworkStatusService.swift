import Foundation
import Network
import SafariLikeContracts

/// Process-wide network path monitor.
///
/// Notes:
/// - The service emits coarse, privacy-safe status snapshots.
/// - It is safe to start monitoring multiple times; only one monitor will run.
public final class NetworkStatusService: @unchecked Sendable {
    /// SAFE SINGLETON:
    /// - Process-wide network status monitor.
    /// - Emits coarse snapshots; must not track per-scene/tab identity.
    public static let shared = NetworkStatusService()

    public var onUpdate: (@Sendable (NetworkStatusSnapshot) -> Void)?

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "SafariLikeCoreKit.NetworkStatusService")

    private let lock = NSLock()
    private var _isStarted: Bool = false
    private var _latest: NetworkStatusSnapshot?

    public var latest: NetworkStatusSnapshot? {
        lock.lock(); defer { lock.unlock() }
        return _latest
    }

    private init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
    }

    public func start() {
        lock.lock()
        let shouldStart = !_isStarted
        _isStarted = true
        lock.unlock()

        guard shouldStart else { return }

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let snapshot = Self.snapshot(from: path)

            self.lock.lock()
            self._latest = snapshot
            let handler = self.onUpdate
            self.lock.unlock()

            handler?(snapshot)
        }

        monitor.start(queue: queue)

        // Emit a best-effort initial snapshot.
        let snapshot = Self.snapshot(from: monitor.currentPath)
        lock.lock()
        _latest = snapshot
        let handler = onUpdate
        lock.unlock()
        handler?(snapshot)
    }

    public func stop() {
        lock.lock()
        let shouldStop = _isStarted
        _isStarted = false
        lock.unlock()

        guard shouldStop else { return }
        monitor.cancel()
    }

    private static func snapshot(from path: NWPath) -> NetworkStatusSnapshot {
        let status: NetworkPathStatus
        switch path.status {
        case .satisfied:
            status = .satisfied
        case .unsatisfied:
            status = .unsatisfied
        case .requiresConnection:
            status = .requiresConnection
        @unknown default:
            status = .unknown
        }

        let primary: NetworkInterfaceType?
        if path.usesInterfaceType(.wifi) {
            primary = .wifi
        } else if path.usesInterfaceType(.cellular) {
            primary = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            primary = .wiredEthernet
        } else if path.usesInterfaceType(.loopback) {
            primary = .loopback
        } else {
            primary = nil
        }

        return NetworkStatusSnapshot(
            status: status,
            primaryInterface: primary,
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained,
            supportsIPv4: path.supportsIPv4,
            supportsIPv6: path.supportsIPv6,
            timestamp: Date()
        )
    }
}
