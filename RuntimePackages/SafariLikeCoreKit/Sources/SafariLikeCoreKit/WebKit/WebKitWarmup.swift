import Foundation
import WebKit

public enum WarmupPolicy: Sendable {
    case disabled
    case afterFirstFrame
    case afterRestore
}

@MainActor
public final class WebKitWarmup {
    /// SAFE SINGLETON:
    /// - Process-wide WebKit warmup controller.
    /// - Must not store per-window/scene/tab mutable state.
    public static let shared = WebKitWarmup()

    /// Called once after the first WKWebView is created (warmup or otherwise).
    public nonisolated(unsafe) static var onFirstWebViewCreated: (@MainActor () -> Void)?

    public var policy: WarmupPolicy = .afterFirstFrame

    private var didWarmup = false
    private static var didFireFirstWebViewCreated = false

    private init() {}

    public func warmupIfNeeded() async {
        guard didWarmup == false else { return }
        guard policy != .disabled else { return }

        didWarmup = true

        let factory = WebViewConfigurationFactory()
        let config = factory.makeConfiguration(profile: .regular)

        // Hidden warmup webview: not attached to any view hierarchy.
        let webView = WebViewPool.makeWebView(configuration: config)

        if Self.didFireFirstWebViewCreated == false {
            Self.didFireFirstWebViewCreated = true
            Self.onFirstWebViewCreated?()
        }

        if let url = URL(string: "about:blank") {
            webView.load(URLRequest(url: url))
        }

        // Let WebKit spin up its processes briefly, then release.
        try? await Task.sleep(nanoseconds: 150_000_000)

    }
}
