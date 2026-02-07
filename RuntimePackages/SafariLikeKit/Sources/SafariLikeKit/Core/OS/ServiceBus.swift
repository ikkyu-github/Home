import Foundation
import SafariLikeCoreKit
// MARK: - Tiny Service Bus (Phase 1)
//
// IPC substitute that is:
// - in-memory
// - type-erased
// - intentionally minimal
//
// Phase 2 will add permission checks, service ownership, and request signing.
struct ServiceRequest {
    let callerPID: Int
    let callerBundleID: String
    let name: String
    let payload: [String: Any]
}
struct ServiceResponse {
    let ok: Bool
    let payload: [String: Any]
    let errorMessage: String?
    static func success(_ payload: [String: Any] = [:]) -> ServiceResponse {
        .init(ok: true, payload: payload, errorMessage: nil)
    }
    static func failure(_ message: String, payload: [String: Any] = [:]) -> ServiceResponse {
        .init(ok: false, payload: payload, errorMessage: message)
    }
}
final class ServiceBus {
    typealias Handler = (ServiceRequest) -> ServiceResponse
    /// SAFE SINGLETON:
    /// - Process-wide in-memory service bus scaffold.
    /// - Must not store per-window/scene/tab UI state.
    static let shared = ServiceBus()
    private var handlers: [String: Handler] = [:]
    private let lock = NSLock()
    private init() {}
    func register(_ name: String, handler: @escaping Handler) {
        lock.lock(); defer { lock.unlock() }
        handlers[name] = handler
    }
    func unregister(_ name: String) {
        lock.lock(); defer { lock.unlock() }
        handlers.removeValue(forKey: name)
    }
    public func call(_ request: ServiceRequest) -> ServiceResponse {
        lock.lock()
        let handler = handlers[request.name]
        lock.unlock()
        guard let handler else {
            return .failure("Service not found: \(request.name)")
        }
        return handler(request)
    }
}
