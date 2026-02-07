import SafariLikeContracts
import SafariLikeCoreKit
/// SafariLikeKit re-exports the primary plugin protocol from SafariLikeContracts.
///
/// This keeps SafariLikeContracts as the single source of truth for the plugin API
/// and avoids accidentally pulling Core types into the plugin boundary.
public typealias BrowserPlugin = SafariLikeContracts.BrowserPlugin
public typealias BrowserPluginContract = SafariLikeContracts.BrowserPluginContract
