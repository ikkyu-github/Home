import Foundation

/// Pure Core protocol: memory pressure notification without UIApplication dependency.
/// Implementations (MemoryPressureObserver) live in SafariLikeCoreKit but connect to UIKit
/// only if canImport(UIKit) is true, and only internally.
public protocol MemoryPressureNotifying: Sendable {
    /// Register a callback for memory pressure events.
    /// - Returns: Token to remove the observer
    func onMemoryPressure(_ callback: @escaping @MainActor (MemoryPressureEvent) -> Void) -> UUID

    /// Unregister observer
    func removeMemoryPressureObserver(_ token: UUID)
}

public enum MemoryPressureEvent: Sendable, Equatable {
    case warning
    case critical
    case stable
}
