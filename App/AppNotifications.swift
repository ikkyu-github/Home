import Foundation

extension Notification.Name {

    /// App-wide dark mode toggle
    /// object: Bool (true = dark, false = light)
    static let appDarkModeChanged =
        Notification.Name("appDarkModeChanged")
}
