import Foundation
import Combine
import SafariLikeCoreKit
/// Central policy controller for Chrome UI behaviors (height, url bar mode, keyboard, animation, split view)
final class ChromePolicyController: ObservableObject {
    // MARK: - Published Policy State
    @Published var urlBarMode: URLBarMode = .idle
    @Published var isAddressEditing: Bool = false
    @Published var isURLBarFocused: Bool = false
    @Published var chromeHeight: Double = 56 // Default, can be set by device
    @Published var keyboardLift: Double = 0
    @Published var isSplitView: Bool = false
    enum URLBarMode: Equatable {
        case idle
        case editing
    }
    // MARK: - Device Policy
    // UI-specific logic removed from Core layer
    // Device-specific logic should be handled by UI layer via protocol/callback if needed
    // MARK: - URL Bar Mode
    func setURLBarMode(editing: Bool) {
        urlBarMode = editing ? .editing : .idle
        isAddressEditing = editing
        isURLBarFocused = editing
    }
    // MARK: - Keyboard
    func setKeyboardLift(_ lift: CGFloat) {
        keyboardLift = lift
    }
    // MARK: - Animation
    // Animation logic removed from Core layer. UI should handle animation.
}
