import Foundation
/// Public-facing abstraction for the internal TabManager.
///
/// This protocol is intentionally minimal; it serves primarily as a
/// type-safe handle that app-level code can pass around or store in
/// SwiftUI environment without depending on TabManager's concrete
/// implementation details.
public protocol BrowserTabManaging: AnyObject {
	@MainActor
	func shutdown() async
	// MARK: - Plugins (per-window)
	/// Enable a compile-time plugin by ID for this window.
	///
	/// Implementations must forward to the per-window PluginHost.
	@MainActor
	func enablePlugin(id: String) async
	/// Disable a compile-time plugin by ID for this window.
	///
	/// Implementations must forward to the per-window PluginHost.
	@MainActor
	func disablePlugin(id: String) async
}
