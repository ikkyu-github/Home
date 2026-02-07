import Foundation

/// Safari-like address bar UI rendering state.
public enum AddressBarUIState: Equatable, Sendable {
    public enum Security: Equatable, Sendable {
        case secure
        case insecure
        case unknown

        public var iconSystemName: String {
            switch self {
            case .secure: return "lock.fill"
            case .insecure: return "exclamationmark.triangle.fill"
            case .unknown: return "magnifyingglass"
            }
        }
    }

    case idle(urlDisplayed: String, security: Security)
    case focused(textDraft: String)
    case editing(queryOrURL: String)
    case loading(progress: Double?, urlDisplayed: String, security: Security)
    case securityInfoDisplayed(urlDisplayed: String, security: Security)

    public var isTextInputFocused: Bool {
        switch self {
        case .focused, .editing:
            return true
        case .idle, .loading, .securityInfoDisplayed:
            return false
        }
    }

    public var textFieldText: String {
        switch self {
        case .idle(let urlDisplayed, _):
            return urlDisplayed
        case .focused(let textDraft):
            return textDraft
        case .editing(let queryOrURL):
            return queryOrURL
        case .loading(_, let urlDisplayed, _):
            return urlDisplayed
        case .securityInfoDisplayed(let urlDisplayed, _):
            return urlDisplayed
        }
    }

    public var securityIconSystemName: String {
        switch self {
        case .idle(_, let security):
            return security.iconSystemName
        case .loading(_, _, let security):
            return security.iconSystemName
        case .securityInfoDisplayed(_, let security):
            return security.iconSystemName
        case .focused, .editing:
            // Safari shows a search glyph while editing.
            return "magnifyingglass"
        }
    }

    public var progress: Double? {
        switch self {
        case .loading(let progress, _, _):
            return progress
        default:
            return nil
        }
    }

    public var isSecurityInfoPresented: Bool {
        if case .securityInfoDisplayed = self { return true }
        return false
    }

    public var shouldShowClearButton: Bool {
        switch self {
        case .focused(let textDraft):
            return textDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .editing(let queryOrURL):
            return queryOrURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        default:
            return false
        }
    }
}

/// Events coming from UI + runtime that drive the address bar UI state machine.
public enum AddressBarUIEvent: Equatable, Sendable {
    case tapAddressBar
    case focusChanged(isFocused: Bool)
    case textChanged(String)
    case submit

    case navigationCommitted(urlString: String)
    case loadingChanged(isLoading: Bool, progress: Double)

    case tapLockIcon
    case tapOutside
    case dismissSecurityInfo
    case clearText
}

/// Deterministic, side-effect-free address bar UI state machine.
public struct AddressBarUIStateMachine: Sendable {
    public struct Snapshot: Sendable, Equatable {
        public var committedURLString: String
        public var state: AddressBarUIState

        public init(committedURLString: String, state: AddressBarUIState) {
            self.committedURLString = committedURLString
            self.state = state
        }
    }

    public private(set) var state: AddressBarUIState

    /// The last committed URL string (full, as received from WebKit/session store).
    private var committedURLString: String

    public init(initialURLString: String) {
        self.committedURLString = initialURLString
        let displayed = Self.simplifiedDisplayText(for: initialURLString)
        self.state = .idle(urlDisplayed: displayed, security: Self.security(for: initialURLString))
    }

    public init(snapshot: Snapshot) {
        self.committedURLString = snapshot.committedURLString
        self.state = snapshot.state
    }

    public func snapshot() -> Snapshot {
        Snapshot(committedURLString: committedURLString, state: state)
    }

    public mutating func restore(_ snapshot: Snapshot) {
        self.committedURLString = snapshot.committedURLString
        self.state = snapshot.state
    }

    public mutating func transition(_ event: AddressBarUIEvent) {
        switch (state, event) {
        // MARK: Tap address bar
        case (.idle, .tapAddressBar), (.idle, .focusChanged(isFocused: true)):
            state = .focused(textDraft: committedURLString)

        case (.focused, .tapAddressBar), (.editing, .tapAddressBar):
            break

        case (.loading, .tapAddressBar):
            state = .focused(textDraft: committedURLString)

        case (.securityInfoDisplayed, .tapAddressBar):
            state = .focused(textDraft: committedURLString)

        // MARK: Typing
        case (.focused, .textChanged(let text)):
            state = .editing(queryOrURL: text)

        case (.editing, .textChanged(let text)):
            state = .editing(queryOrURL: text)

        case (.idle, .textChanged(let text)):
            state = .editing(queryOrURL: text)

        case (.loading, .textChanged(let text)):
            state = .editing(queryOrURL: text)

        case (.securityInfoDisplayed, .textChanged(let text)):
            state = .editing(queryOrURL: text)

        // MARK: Submit
        case (.editing(let text), .submit):
            state = .loading(progress: nil, urlDisplayed: text, security: Self.security(for: committedURLString))

        // MARK: Navigation committed
        case (_, .navigationCommitted(let urlString)):
            committedURLString = urlString
            let displayed = Self.simplifiedDisplayText(for: urlString)
            let security = Self.security(for: urlString)

            switch state {
            case .loading:
                state = .idle(urlDisplayed: displayed, security: security)
            case .idle:
                state = .idle(urlDisplayed: displayed, security: security)
            case .focused, .editing:
                // While editing, do not overwrite the user's draft.
                break
            case .securityInfoDisplayed:
                state = .securityInfoDisplayed(urlDisplayed: displayed, security: security)
            }

        // MARK: Loading changed
        case (.loading(_, let urlDisplayed, let security), .loadingChanged(let isLoading, let progress)):
            if isLoading {
                state = .loading(progress: progress, urlDisplayed: urlDisplayed, security: security)
            } else {
                state = .idle(urlDisplayed: Self.simplifiedDisplayText(for: committedURLString), security: Self.security(for: committedURLString))
            }

        case (.idle, .loadingChanged(let isLoading, let progress)):
            if isLoading {
                state = .loading(progress: progress, urlDisplayed: Self.simplifiedDisplayText(for: committedURLString), security: Self.security(for: committedURLString))
            }

        case (.focused, .loadingChanged), (.editing, .loadingChanged):
            break

        case (.securityInfoDisplayed, .loadingChanged):
            break

        // MARK: Lock icon
        case (.idle(let urlDisplayed, let security), .tapLockIcon):
            state = .securityInfoDisplayed(urlDisplayed: urlDisplayed, security: security)

        case (.loading(_, let urlDisplayed, let security), .tapLockIcon):
            state = .securityInfoDisplayed(urlDisplayed: urlDisplayed, security: security)

        // MARK: Tap outside
        case (.focused, .tapOutside), (.editing, .tapOutside), (.focused, .focusChanged(isFocused: false)), (.editing, .focusChanged(isFocused: false)):
            state = .idle(urlDisplayed: Self.simplifiedDisplayText(for: committedURLString), security: Self.security(for: committedURLString))

        case (.securityInfoDisplayed, .tapOutside), (.securityInfoDisplayed, .dismissSecurityInfo):
            state = .idle(urlDisplayed: Self.simplifiedDisplayText(for: committedURLString), security: Self.security(for: committedURLString))

        // MARK: Clear
        case (.focused, .clearText):
            state = .editing(queryOrURL: "")

        case (.editing, .clearText):
            state = .editing(queryOrURL: "")

        case (.loading, .clearText):
            state = .editing(queryOrURL: "")

        case (.idle, .clearText), (.securityInfoDisplayed, .clearText):
            break

        // MARK: No-ops
        case (_, .focusChanged):
            break

        case (_, .tapOutside):
            break

        case (_, .dismissSecurityInfo):
            break

        case (_, .tapLockIcon):
            break

        case (_, .submit):
            break
        }
    }

    // MARK: - Helpers
    public static func simplifiedDisplayText(for urlString: String) -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "" }
        if trimmed == "about:blank" { return "" }

        var s = trimmed
        if s.lowercased().hasPrefix("https://") {
            s.removeFirst("https://".count)
        } else if s.lowercased().hasPrefix("http://") {
            s.removeFirst("http://".count)
        }

        if s.count > 1, s.hasSuffix("/") {
            s.removeLast()
        }

        return s
    }

    public static func security(for urlString: String) -> AddressBarUIState.Security {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else {
            return .unknown
        }
        switch scheme {
        case "https": return .secure
        case "http": return .insecure
        default: return .unknown
        }
    }
}
