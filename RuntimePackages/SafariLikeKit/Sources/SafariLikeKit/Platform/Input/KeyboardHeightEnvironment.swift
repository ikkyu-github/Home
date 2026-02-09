import SwiftUI

private struct KeyboardHeightEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Current on-screen keyboard height in the key window's coordinate space.
    ///
    /// Defaults to 0 when no observer is installed by the root.
    var keyboardHeight: CGFloat {
        get { self[KeyboardHeightEnvironmentKey.self] }
        set { self[KeyboardHeightEnvironmentKey.self] = newValue }
    }
}
