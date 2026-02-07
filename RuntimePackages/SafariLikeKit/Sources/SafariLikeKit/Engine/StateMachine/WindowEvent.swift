import Foundation
import SafariLikeCoreKit
public enum WindowEvent: Equatable {
    case openWindow
    case closeWindow
    case activateWindow
    case persistSessionNow
    case restoreSession
}
