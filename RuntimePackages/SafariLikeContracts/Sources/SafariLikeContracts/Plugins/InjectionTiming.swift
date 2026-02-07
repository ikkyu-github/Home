import Foundation

/// When to inject content scripts/styles relative to page load.
public enum InjectionTiming: String, Codable, Sendable {
    case atDocumentStart
    case afterDocumentEnd
}
