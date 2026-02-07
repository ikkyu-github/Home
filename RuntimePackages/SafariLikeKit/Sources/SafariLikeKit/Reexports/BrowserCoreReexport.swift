import SafariLikeCoreKit

// App-layer safe reexports.
//
// App targets must not import `BrowserCore` directly. These typealiases allow the App
// to depend only on `SafariLikeKit` while keeping BrowserCore UI-free.
public typealias DownloadCenter = SafariLikeCoreKit.DownloadCenter
