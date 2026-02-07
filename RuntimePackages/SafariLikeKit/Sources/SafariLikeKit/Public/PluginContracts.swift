import SafariLikeContracts
import SafariLikeCoreKit
/// Re-exported from `SafariLikeContracts` for app-facing settings UIs.
/// Underlying permission type used throughout SafariLikeKit.
///
/// Note: app targets should avoid switching over cases directly. Use `PluginPermissions`
/// helpers instead, to keep the app facade-only under MemberImportVisibility.
public typealias PluginPermission = SafariLikeContracts.PluginPermission
public enum PluginPermissions {
	public static var all: [PluginPermission] {
		SafariLikeContracts.PluginPermission.allCases
	}
	public static func key(_ permission: PluginPermission) -> String {
		permission.rawValue
	}
}
