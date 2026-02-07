import Foundation
import Combine
import SafariLikeContracts
import SafariLikeCoreKit

@MainActor
public final class NetworkDiagnosticsModel: ObservableObject {
    /// SAFE SINGLETON:
    /// - Process-wide diagnostics surface (network is process-wide).
    /// - Must not store per-window/scene/tab mutable state.
    public static let shared = NetworkDiagnosticsModel()

    @Published public private(set) var networkStatus: NetworkStatusSnapshot?
    @Published public private(set) var recentNavigationFailures: [NavigationFailureRecord] = []

    private let network = NetworkStatusService.shared

    private init() {
        network.onUpdate = { [weak self] snapshot in
            Task { @MainActor [weak self] in
                self?.networkStatus = snapshot
            }
        }
        network.start()
    }

    public func recordNavigationFailure(_ record: NavigationFailureRecord, cap: Int = 50) {
        recentNavigationFailures.insert(record, at: 0)
        if recentNavigationFailures.count > cap {
            recentNavigationFailures.removeLast(recentNavigationFailures.count - cap)
        }
    }

    public func clearFailures() {
        recentNavigationFailures.removeAll()
    }
}
