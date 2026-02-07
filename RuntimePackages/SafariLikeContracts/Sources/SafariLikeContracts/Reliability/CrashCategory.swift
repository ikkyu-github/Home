import Foundation

public enum CrashCategory: String, Codable, Sendable, Hashable {
    case invariantViolation
    case illegalStateTransition
    case resourceLeak
    case unexpectedNil
    case concurrencyViolation
}
