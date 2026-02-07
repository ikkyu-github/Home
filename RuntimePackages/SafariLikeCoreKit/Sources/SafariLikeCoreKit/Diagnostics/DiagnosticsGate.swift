import Foundation

public enum DiagnosticsGate {
    /// Shared UserDefaults key. Set via App Settings UI.
    public static let enabledKey = "app.diagnostics.enabled"

    public static var isEnabled: Bool {
        if let value = UserDefaults.standard.object(forKey: enabledKey) as? Bool {
            return value
        }
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
