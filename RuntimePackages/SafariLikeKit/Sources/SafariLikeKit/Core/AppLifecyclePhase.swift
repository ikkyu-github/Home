import SafariLikeCoreKit
// Core abstraction for app lifecycle, to decouple from SwiftUI
enum AppLifecyclePhase {
    case active
    case inactive
    case background
}
