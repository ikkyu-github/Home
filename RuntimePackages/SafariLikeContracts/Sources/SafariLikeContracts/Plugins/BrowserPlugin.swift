import Foundation
import ObjectiveC

/// Primary plugin interface for SafariLike.
///
/// ## Boundary rules
/// Plugins are intended to compile against **SafariLikeContracts only**.
/// This protocol deliberately depends only on Foundation + Contracts types.
///
/// The host (SafariLikeKit) provides a concrete context object that conforms to
/// `BrowserPluginContext` and forwards calls into Core-owned services.
@MainActor
public protocol BrowserPlugin: AnyObject {
    /// Required for dynamic instantiation.
    init()

    /// Stable reverse-domain identifier (e.g. "com.example.my-plugin").
    var id: String { get }

    /// Declared capabilities for this plugin.
    var capabilities: Set<PluginCapability> { get }

    /// Classification used by the host (e.g. only `.policy` plugins can block navigation).
    var kind: PluginKind { get }

    /// Optional metadata surfaced to the UI layer.
    var name: String { get }
    var version: String { get }
    var author: String { get }

    /// Ordering hint. Higher numbers run earlier.
    var priority: Int { get }

    /// Host-maintained lifecycle state.
    var lifecycleState: PluginLifecycleState { get set }

    /// Convenience descriptor used across the plugin runtime.
    var descriptor: PluginDescriptor { get }

    // MARK: - Lifecycle

    func onLoad(context: any BrowserPluginContext) async throws
    func onEnable() async throws
    func onDisable() async
    func onUnload() async throws

    // MARK: - Policy

    /// Policy check for navigation. Only consulted when `kind == .policy`.
    func shouldAllowNavigation(_ request: URLRequest) -> Bool

    // MARK: - WebView / Tab lifecycle (optional)

    func webViewWillDetach(tabID: String) async throws
    func tabWillEvict(tabID: String) async throws

    // MARK: - Simple navigation notifications (optional)

    func navigationWillStart(url: URL) throws
    func navigationDidFinish(url: URL) throws
    func navigationDidFail(url: URL, error: Error) throws
}

public extension BrowserPlugin {
    var name: String { String(describing: Self.self) }
    var version: String { "0.0.0" }
    var author: String { "" }
    var kind: PluginKind { .feature }
    var priority: Int { 0 }

    var descriptor: PluginDescriptor {
        PluginDescriptor(
            id: id,
            name: name,
            version: version,
            author: author,
            kind: kind
        )
    }

    var lifecycleState: PluginLifecycleState {
        get { _lifecycleBox.state }
        set { _lifecycleBox.state = newValue }
    }

    func onEnable() async throws {}
    func onDisable() async {}
    func onUnload() async throws {}

    func shouldAllowNavigation(_ request: URLRequest) -> Bool { true }

    func webViewWillDetach(tabID: String) async throws {}
    func tabWillEvict(tabID: String) async throws {}

    func navigationWillStart(url: URL) throws {}
    func navigationDidFinish(url: URL) throws {}
    func navigationDidFail(url: URL, error: Error) throws {}
}

private final class _BrowserPluginLifecycleBox {
    var state: PluginLifecycleState = .unloaded
}

private enum _BrowserPluginAssociatedKeys {
    static var lifecycle: UInt8 = 0
}

private extension BrowserPlugin {
    var _lifecycleBox: _BrowserPluginLifecycleBox {
        let key = UnsafeRawPointer(&_BrowserPluginAssociatedKeys.lifecycle)
        if let existing = objc_getAssociatedObject(self, key) as? _BrowserPluginLifecycleBox {
            return existing
        }
        let created = _BrowserPluginLifecycleBox()
        objc_setAssociatedObject(self, key, created, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return created
    }
}

/// Backward-compatibility alias. Prefer `BrowserPlugin`.
public typealias BrowserPluginContract = BrowserPlugin
