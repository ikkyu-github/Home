import Foundation

/// Immutable description of a navigation request observed or
/// intercepted by the plugin system.
public struct NavigationRequest: Sendable {
    public let url: String
    public let method: String
    public let headers: [String: String]
    public let isMainFrame: Bool

    public init(url: String, method: String, headers: [String: String], isMainFrame: Bool) {
        self.url = url
        self.method = method
        self.headers = headers
        self.isMainFrame = isMainFrame
    }
}

/// High-level navigation events exposed to plugins with
/// `.navigationRead` capability.
public enum NavigationEvent: Sendable {
    case navigationDidStart(NavigationRequest)
    case navigationDidFinish(NavigationRequest)
    case navigationDidFail(NavigationRequest, Error)
    case tabDidChange(from: String, to: String)
}

/// Result of a navigation interception hook.
public enum InterceptionResponse: Sendable {
    case allow
    case cancel
    case redirect(URL)
    case block
    case synthesize(SyntheticResponse)
}
