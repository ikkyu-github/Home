import Foundation
import SafariLikeCoreKit
public enum TabEffect: Equatable {
    case persistTab(tabID: UUID)
    case loadWebView(tabID: UUID, url: URL)
    case closeWebView(tabID: UUID)
    case showError(tabID: UUID, errorCode: Int?, errorDomain: String, errorDescription: String?)
    case updateSnapshot(tabID: UUID)
    case takeSnapshot(tabID: UUID)
    case detachWebView(tabID: UUID)
    case attachWebView(tabID: UUID)
}
