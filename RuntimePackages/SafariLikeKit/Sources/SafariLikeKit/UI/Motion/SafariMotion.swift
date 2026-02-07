import SwiftUI
import SafariLikeCoreKit
enum SafariMotion {
    /// Safari-like spring tuning (no easeInOut).
    static let response: Double = 0.28
    static let dampingFraction: Double = 0.90
    static var spring: Animation {
        .interactiveSpring(response: response, dampingFraction: dampingFraction, blendDuration: 0)
    }
}
