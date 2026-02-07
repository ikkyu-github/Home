import Foundation
import SafariLikeCoreKit
/// A high-level category for a fault so the app can apply domain-specific recovery.
public enum FaultDomain: String, Codable, Sendable {
    case plugin
    case webRuntime
    case ui
    case persistence
}
