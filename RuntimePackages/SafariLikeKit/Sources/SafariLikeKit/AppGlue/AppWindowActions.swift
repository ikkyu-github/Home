import UIKit
import SafariLikeCoreKit
/// ตัวช่วยสำหรับจัดการการเปิดหน้าต่าง/ซีนใหม่ของแอปที่ฝัง SafariLikeKit.
///
/// ใช้ร่วมกับ ``AppMenuCommands`` หรือปุ่ม/เมนูอื่น ๆ ในแอปเพื่อรองรับหลายหน้าต่าง
/// บน iPadOS โดยไม่ต้องรู้รายละเอียดภายในของ SafariLikeKit.
///
/// **Multi-Window Support:**
/// - `openNewWindow()` - Requests a new scene session activation
/// - `duplicateCurrentWindow()` - Requests a new scene session activation
///
/// Contract:
/// - Do not branch behavior by device idiom (iPhone/iPad).
/// - Let the OS decide whether additional scenes are supported.
enum AppWindowActions {
    // Window-scoped bridge for platforms/contexts where multi-scene is unavailable.
    @MainActor
    private static weak var sessionRegistry: AppBrowserSessionRegistry?
    /// Bind the window-scoped session registry so AppWindowActions can fall back to
    /// an in-scene logical window when multi-scene is not supported.
    @MainActor
    static func bind(sessionRegistry: AppBrowserSessionRegistry) {
        self.sessionRegistry = sessionRegistry
    }
    // MARK: - Legacy Support
    /// Legacy method for opening new window (kept for backward compatibility).
    /// Automatically handles device limitations.
    @MainActor
    public static func openNewWindowIfSupported() {
        openNewWindow()
    }
    // MARK: - Multi-Window Actions
    /// Opens a new browser window using the session registry.
    ///
    /// **Behavior:**
    /// - iPad: Creates new window via WindowGroup
    /// - iPhone: Maps a logical "window" to a new tab group + tab in the active session
    ///
    /// **Flow:**
    /// 1. Requests a new WindowGroup scene via requestSceneSessionActivation() (when supported)
    /// 2. New window initializes with a fresh scene session + ViewModel
    ///
    /// **Example:**
    /// ```swift
    /// Button("New Window") {
    ///     AppWindowActions.openNewWindow()
    /// }
    /// .keyboardShortcut("n", modifiers: [.command])
    /// ```
    @MainActor
    public static func openNewWindow() {
        #if os(iOS)
        if UIApplication.shared.supportsMultipleScenes {
            UIApplication.shared.requestSceneSessionActivation(
                nil,
                userActivity: nil,
                options: nil
            )
        } else {
            // Fallback (iPhone / single-scene): create a new logical window as a tab group.
            guard let session = sessionRegistry?.activeSession else { return }
            let name = "New Window"
            let groupID = session.viewModel.sessionStore.createTabGroup(name: name, color: .blue)
            session.viewModel.selectTabGroup(groupID)
            session.viewModel.newTab(inGroup: groupID)
        }
        #endif
    }
    // MARK: - URL Routing
    /// Open a URL either in the current window or in a new window (scene).
    ///
    /// Rules:
    /// - `inNewWindow == true`: request a new scene (when supported) and route the URL into it.
    /// - `inNewWindow == false`: load into the active tab of the current window.
    @MainActor
    public static func openURL(_ url: URL, inNewWindow: Bool) {
        #if os(iOS)
        if inNewWindow {
            if UIApplication.shared.supportsMultipleScenes {
                UIApplication.shared.requestSceneSessionActivation(
                    nil,
                    userActivity: OpenURLUserActivity.make(url: url),
                    options: nil
                )
            } else {
                // Fallback (iPhone / single-scene): treat as a new logical window (tab group).
                guard let session = sessionRegistry?.activeSession else { return }
                let name = url.host ?? "New Window"
                let groupID = session.viewModel.sessionStore.createTabGroup(name: name, color: .blue)
                session.viewModel.selectTabGroup(groupID)
                session.viewModel.openTab(urlString: url.absoluteString, inBackground: false)
            }
        } else {
            guard let session = sessionRegistry?.activeSession else { return }
            session.viewModel.open(url)
        }
        #else
        _ = (url, inNewWindow)
        #endif
    }
    /// Duplicates the current window with similar state.
    ///
    /// **Behavior:**
    /// - iPad: Creates new window with fresh session
    /// - iPhone: Creates a new tab group with duplicated tabs from the current logical window
    ///
    /// **Future Enhancement:**
    /// - Could copy current window's state to new window
    /// - Copy tabs, active tab, scroll position, etc.
    ///
    /// **Example:**
    /// ```swift
    /// Button("Duplicate Window") {
    ///     AppWindowActions.duplicateCurrentWindow()
    /// }
    /// ```
    @MainActor
    public static func duplicateCurrentWindow() {
        #if os(iOS)
        if UIApplication.shared.supportsMultipleScenes {
            UIApplication.shared.requestSceneSessionActivation(
                nil,
                userActivity: nil,
                options: nil
            )
        } else {
            // Best-effort: treat as a new logical window for single-scene environments.
            openNewWindow()
        }
        #endif
    }
}
