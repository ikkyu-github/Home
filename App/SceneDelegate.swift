// SceneDelegate.swift remains disabled.
//
// Multi-window (Safari-like) behavior is implemented via:
// - SwiftUI `WindowGroup`
// - Per-scene stable `BrowserWindowID` stored in `@SceneStorage` (see AppRootView)
// - UISceneSession.userInfo metadata (for discard callbacks)
// - Runtime-owned WebView lifecycles (no SwiftUI lifecycle destruction)
//
// If switching back to UIKit-driven scenes later, re-enable this file and
// re-add a complete UIApplicationSceneManifest to Info.plist.
#if false
import UIKit
import SwiftUI
import AVFoundation
import os

@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
}
#endif
