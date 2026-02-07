@_exported import BrowserCore

// SafariLikeCoreKit is allowed to depend on BrowserCore.
// SafariLikeKit (facade) should avoid importing BrowserCore directly.

public typealias BrowserSessionStore = BrowserCore.BrowserSessionStore
public typealias BrowserTab = BrowserCore.BrowserTab
public typealias BrowserTabGroup = BrowserCore.BrowserTabGroup
public typealias TabLifecycleState = BrowserCore.TabLifecycleState
public typealias TabDiscardConfig = BrowserCore.TabDiscardConfig
public typealias TabResourcePolicy = BrowserCore.TabResourcePolicy
public typealias WindowSessionState = BrowserCore.WindowSessionState
public typealias DownloadCenter = BrowserCore.DownloadCenter
public typealias UserScriptStore = BrowserCore.UserScriptStore
public typealias UserScriptPersisting = BrowserCore.UserScriptPersisting
