import Foundation
import SafariLikeCoreKit
enum BrowserContracts {
    // MARK: - Notification Names
    public enum Notification {
        public static let appDarkModeChanged = Foundation.Notification.Name("app.darkMode.changed")
        public static let processStarted = Foundation.Notification.Name("ProcessManager.processStarted")
        public static let processStateChanged = Foundation.Notification.Name("ProcessManager.processStateChanged")
        public static let processTerminated = Foundation.Notification.Name("ProcessManager.processTerminated")
    }
    // MARK: - UserDefaults Keys (add here if found)
    // public enum UserDefaultsKey {
    //     public static let exampleKey = "exampleKey"
    // }
    // MARK: - File Path Keys (add here if found)
    // public enum FilePath {
    //     public static let examplePath = "examplePath"
    // }
    // MARK: - URL Endpoints (add here if found)
    // public enum URLEndpoint {
    //     public static let exampleURL = "https://example.com"
    // }
}
