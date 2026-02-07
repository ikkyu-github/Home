import SafariLikeCoreKit
/// Thin facade to ensure SafariLikeKit uses BrowserCore's BrowserSessionStore
/// as the single source of truth for session persistence.
///
/// SafariLikeKit must not create or manage session snapshots directly;
/// all snapshot logic lives inside `SafariLikeCoreKit.BrowserSessionStore`.
public typealias BrowserSessionStore = SafariLikeCoreKit.BrowserSessionStore
