import Combine
import Dispatch
import Foundation
import os
import SafariLikeContracts
import SafariLikeCoreKit
@MainActor
final class RuntimePluginRegistry: ObservableObject {
    private static let logger = Logger(subsystem: "SafariLikeKit", category: "RuntimePluginRegistry")
    private static let hookTimeoutNanoseconds: UInt64 = 200_000_000
    weak var faultManager: FaultManager?
    private struct PluginHookTimeoutError: Error, CustomStringConvertible {
        let pluginID: String
        let hook: String
        let timeoutMilliseconds: Int
        var description: String {
            "Plugin hook timed out (id=\(pluginID), hook=\(hook), timeoutMs=\(timeoutMilliseconds))"
        }
    }
    private enum _TimeoutOutcome<T> {
        case success(T)
        case timeout
    }
    private enum _HookResult<T> {
        case ok(T)
        case error(Error)
    }
    private func runHookWithTimeout<T>(
        pluginID: String,
        hook: String,
        nanoseconds: UInt64,
        operation: @escaping @MainActor () async throws -> T
    ) async -> _TimeoutOutcome<_HookResult<T>> {
        let hookTask = Task { @MainActor in
            do {
                return _HookResult.ok(try await operation())
            } catch {
                return _HookResult.error(error)
            }
        }
        let outcome: _TimeoutOutcome<_HookResult<T>> = await withTaskGroup(of: _TimeoutOutcome<_HookResult<T>>.self) { group in
            group.addTask {
                let value = await hookTask.value
                return .success(value)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: nanoseconds)
                return .timeout
            }
            let first = await group.next() ?? .timeout
            group.cancelAll()
            return first
        }
        if case .timeout = outcome {
            hookTask.cancel()
        }
        return outcome
    }
    private func markFailedAndDisable(pluginID: String, plugin: BrowserPlugin, error: Error) {
        enabledPluginIDs.remove(pluginID)
        plugin.lifecycleState = .failed(error)
        metrics.incrementFailure(pluginID: pluginID)
        Self.logger.error("Auto-disabled failed plugin \(pluginID, privacy: .public): \(String(describing: error), privacy: .public)")
        // Best-effort: record fault into per-window metrics + apply any global recovery policy.
        faultManager?.pluginFault(pluginID: pluginID, message: "Plugin fault: \(String(describing: error))", error: error)
    }
    @Published private(set) var installedPlugins: [String: BrowserPlugin] = [:]
    @Published private(set) var enabledPluginIDs: Set<String> = []
    let metrics = PluginMetricsStore()
    /// Enabled plugins in a deterministic order.
    ///
    /// We avoid iterating Sets directly so plugin execution order is stable.
    func enabledPluginsInOrder() -> [(id: String, plugin: BrowserPlugin)] {
        enabledPluginIDs
            .compactMap { id -> (id: String, plugin: BrowserPlugin)? in
                guard let plugin = installedPlugins[id] else { return nil }
                return (id: id, plugin: plugin)
            }
            .sorted { lhs, rhs in
                let lhsPriority = lhs.plugin.priority
                let rhsPriority = rhs.plugin.priority
                if lhsPriority != rhsPriority { return lhsPriority > rhsPriority }
                return lhs.id < rhs.id
            }
    }
    /// Evaluate policy plugins for a navigation request.
    ///
    /// Rules:
    /// - Only plugins where `descriptor.kind == .policy` are consulted.
    /// - If any policy returns false → navigation must be cancelled.
    func shouldAllowNavigation(
        _ request: URLRequest,
        allowedPluginIDs: Set<String>? = nil
    ) async -> Bool {
        let startedAt = DispatchTime.now().uptimeNanoseconds
        for (id, plugin) in enabledPluginsInOrder() {
            if let allowedPluginIDs, allowedPluginIDs.contains(id) == false {
                continue
            }
            guard plugin.descriptor.kind == .policy else { continue }
            let elapsed = DispatchTime.now().uptimeNanoseconds &- startedAt
            if elapsed >= Self.hookTimeoutNanoseconds {
                metrics.recordPolicyCheck(pluginID: id, durationSeconds: 0)
                let error = PluginHookTimeoutError(
                    pluginID: id,
                    hook: "policyBudget",
                    timeoutMilliseconds: Int(Self.hookTimeoutNanoseconds / 1_000_000)
                )
                markFailedAndDisable(pluginID: id, plugin: plugin, error: error)
                return false
            }
            let remaining = Self.hookTimeoutNanoseconds - elapsed
            let hookStart = DispatchTime.now().uptimeNanoseconds
            let outcome = await runHookWithTimeout(
                pluginID: id,
                hook: "shouldAllowNavigation",
                nanoseconds: remaining
            ) {
                plugin.shouldAllowNavigation(request)
            }
            switch outcome {
            case .success(.ok(let allow)):
                let hookEnd = DispatchTime.now().uptimeNanoseconds
                metrics.recordPolicyCheck(
                    pluginID: id,
                    durationSeconds: TimeInterval(Double(hookEnd - hookStart) / 1_000_000_000)
                )
                if allow == false {
                    return false
                }
            case .success(.error(let error)):
                let hookEnd = DispatchTime.now().uptimeNanoseconds
                metrics.recordPolicyCheck(
                    pluginID: id,
                    durationSeconds: TimeInterval(Double(hookEnd - hookStart) / 1_000_000_000)
                )
                markFailedAndDisable(pluginID: id, plugin: plugin, error: error)
                return false
            case .timeout:
                metrics.recordPolicyCheck(
                    pluginID: id,
                    durationSeconds: TimeInterval(Double(remaining) / 1_000_000_000)
                )
                let error = PluginHookTimeoutError(
                    pluginID: id,
                    hook: "shouldAllowNavigation",
                    timeoutMilliseconds: Int(Self.hookTimeoutNanoseconds / 1_000_000)
                )
                markFailedAndDisable(pluginID: id, plugin: plugin, error: error)
                return false
            }
        }
        return true
    }
    func install(_ plugin: BrowserPlugin, context: PluginContext) async {
        let pluginID = plugin.descriptor.id
        // Replace semantics: if the ID already exists, fully uninstall first.
        if installedPlugins[pluginID] != nil {
            await uninstall(pluginID: pluginID)
        }
        // Per rule: install -> onLoad (bounded)
        let hookStart = DispatchTime.now().uptimeNanoseconds
        let outcome = await runHookWithTimeout(
            pluginID: pluginID,
            hook: "onLoad",
            nanoseconds: Self.hookTimeoutNanoseconds
        ) {
            try await plugin.onLoad(context: context)
        }
        switch outcome {
        case .success(.ok):
            let hookEnd = DispatchTime.now().uptimeNanoseconds
            metrics.recordLoad(
                pluginID: pluginID,
                durationSeconds: TimeInterval(Double(hookEnd - hookStart) / 1_000_000_000)
            )
            plugin.lifecycleState = .loaded
            installedPlugins[pluginID] = plugin
        case .success(.error(let error)):
            let hookEnd = DispatchTime.now().uptimeNanoseconds
            metrics.recordLoad(
                pluginID: pluginID,
                durationSeconds: TimeInterval(Double(hookEnd - hookStart) / 1_000_000_000)
            )
            installedPlugins[pluginID] = plugin
            markFailedAndDisable(pluginID: pluginID, plugin: plugin, error: error)
        case .timeout:
            metrics.recordLoad(
                pluginID: pluginID,
                durationSeconds: TimeInterval(Double(Self.hookTimeoutNanoseconds) / 1_000_000_000)
            )
            installedPlugins[pluginID] = plugin
            let error = PluginHookTimeoutError(
                pluginID: pluginID,
                hook: "onLoad",
                timeoutMilliseconds: Int(Self.hookTimeoutNanoseconds / 1_000_000)
            )
            markFailedAndDisable(pluginID: pluginID, plugin: plugin, error: error)
        }
    }
    func enable(pluginID: String) async {
        guard let plugin = installedPlugins[pluginID] else { return }
        guard enabledPluginIDs.contains(pluginID) == false else { return }
        // Per rule: enable -> onEnable (bounded)
        let hookStart = DispatchTime.now().uptimeNanoseconds
        let outcome = await runHookWithTimeout(
            pluginID: pluginID,
            hook: "onEnable",
            nanoseconds: Self.hookTimeoutNanoseconds
        ) {
            try await plugin.onEnable()
        }
        switch outcome {
        case .success(.ok):
            let hookEnd = DispatchTime.now().uptimeNanoseconds
            metrics.recordEnable(
                pluginID: pluginID,
                durationSeconds: TimeInterval(Double(hookEnd - hookStart) / 1_000_000_000)
            )
            enabledPluginIDs.insert(pluginID)
            plugin.lifecycleState = .enabled
        case .success(.error(let error)):
            let hookEnd = DispatchTime.now().uptimeNanoseconds
            metrics.recordEnable(
                pluginID: pluginID,
                durationSeconds: TimeInterval(Double(hookEnd - hookStart) / 1_000_000_000)
            )
            markFailedAndDisable(pluginID: pluginID, plugin: plugin, error: error)
        case .timeout:
            metrics.recordEnable(
                pluginID: pluginID,
                durationSeconds: TimeInterval(Double(Self.hookTimeoutNanoseconds) / 1_000_000_000)
            )
            let error = PluginHookTimeoutError(
                pluginID: pluginID,
                hook: "onEnable",
                timeoutMilliseconds: Int(Self.hookTimeoutNanoseconds / 1_000_000)
            )
            markFailedAndDisable(pluginID: pluginID, plugin: plugin, error: error)
        }
    }
    func disable(pluginID: String) {
        guard let plugin = installedPlugins[pluginID] else { return }
        guard enabledPluginIDs.contains(pluginID) else {
            // Keep state consistent if callers disable an already-disabled plugin.
            if case .enabled = plugin.lifecycleState {
                plugin.lifecycleState = .disabled
            }
            return
        }
        // Per rule: disable -> onDisable (best-effort)
        Task { @MainActor in
            await plugin.onDisable()
        }
        enabledPluginIDs.remove(pluginID)
        plugin.lifecycleState = .disabled
    }
    func uninstall(pluginID: String) async {
        guard let plugin = installedPlugins[pluginID] else { return }
        // Ensure observable state is consistent even if plugin is removed while enabled.
        enabledPluginIDs.remove(pluginID)
        // Per rule: uninstall -> onUnload (bounded) + remove
        _ = await runHookWithTimeout(
            pluginID: pluginID,
            hook: "onUnload",
            nanoseconds: Self.hookTimeoutNanoseconds
        ) {
            try await plugin.onUnload()
        }
        plugin.lifecycleState = .unloaded
        installedPlugins.removeValue(forKey: pluginID)
        metrics.reset(pluginID: pluginID)
    }
}
