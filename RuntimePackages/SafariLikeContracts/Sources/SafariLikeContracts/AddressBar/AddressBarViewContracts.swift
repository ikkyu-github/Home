import Foundation

/// UI-facing events for driving the Address Bar UI state.
///
/// Notes:
/// - This is intentionally UI-safe (Strings/Bools/Doubles only) so it can be used across app/UI layers
///   without importing CoreKit or WebKit concepts.
/// - Core state transitions remain modeled by `AddressBarState` + `AddressBarAction`.
public enum AddressBarEvent: Sendable, Equatable {
    case tapAddressBar
    case focusChanged(isFocused: Bool)
    case textChanged(String)
    case submit

    /// Convenience intent used by UI: submit then deterministically dismiss editing.
    /// (Implemented by the domain/feature as a small sequence of core events.)
    case submitAndDismissEditing

    case navigationCommitted(urlString: String)
    case loadingChanged(isLoading: Bool, progress: Double)

    case tapLockIcon
    case tapOutside

    /// Convenience intent used by UI: cancel editing and blur.
    /// (Safari-like: restores last committed URL.)
    case cancelEditing

    case dismissSecurityInfo
    case clearText
}

/// Minimal, UI-facing view state for rendering the Address Bar.
///
/// This is a contract type (no UXKit state machine / no WebKit / no CoreKit objects).
public struct AddressBarViewState: Sendable, Equatable {
    public enum Mode: Sendable, Equatable {
        case idle
        case focused
        case editing
        case loading
        case securityInfo
    }

    public enum SecurityIndicator: Sendable, Equatable {
        case secure
        case insecure
        case unknown
    }

    public var mode: Mode
    public var textFieldText: String
    public var isTextInputFocused: Bool
    public var security: SecurityIndicator
    public var loadingProgress: Double?
    public var isSecurityInfoPresented: Bool
    public var shouldShowClearButton: Bool

    public init(
        mode: Mode,
        textFieldText: String,
        isTextInputFocused: Bool,
        security: SecurityIndicator,
        loadingProgress: Double?,
        isSecurityInfoPresented: Bool,
        shouldShowClearButton: Bool
    ) {
        self.mode = mode
        self.textFieldText = textFieldText
        self.isTextInputFocused = isTextInputFocused
        self.security = security
        self.loadingProgress = loadingProgress
        self.isSecurityInfoPresented = isSecurityInfoPresented
        self.shouldShowClearButton = shouldShowClearButton
    }

    public static let empty = AddressBarViewState(
        mode: .idle,
        textFieldText: "",
        isTextInputFocused: false,
        security: .unknown,
        loadingProgress: nil,
        isSecurityInfoPresented: false,
        shouldShowClearButton: false
    )

    /// Renderer helper (keeps Views from depending on UXKit state machine types).
    public var securityIconSystemName: String {
        if mode == .editing || mode == .focused {
            return "magnifyingglass"
        }
        switch security {
        case .secure: return "lock.fill"
        case .insecure: return "exclamationmark.triangle.fill"
        case .unknown: return "magnifyingglass"
        }
    }
}
