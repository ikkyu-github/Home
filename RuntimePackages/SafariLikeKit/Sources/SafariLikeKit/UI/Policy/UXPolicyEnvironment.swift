import SwiftUI
import SafariLikeUXKit
import SafariLikeCoreKit
private struct UXPolicyKey: EnvironmentKey {
    static let defaultValue: UXPolicy = .default
}
public extension EnvironmentValues {
    var uxPolicy: UXPolicy {
        get { self[UXPolicyKey.self] }
        set { self[UXPolicyKey.self] = newValue }
    }
}
