import Foundation
import SafariLikeContracts

/// Side effects produced by `AddressBarFeature`.
///
/// The feature is pure w.r.t. WebKit/runtime; it emits effects for the app layer to execute.
public enum AddressBarEffect: Sendable, Equatable {
    case openURLString(String, force: Bool)
    case search(String)
    case cancel
}

/// UXKit-owned address bar feature:
/// - owns deterministic UI state rules
/// - emits effects for submit/cancel
///
/// The app layer (SafariLikeKit) should not compute policy; it should only route events and run effects.
public struct AddressBarFeature: Sendable {
    public typealias Snapshot = AddressBarUIStateMachine.Snapshot

    private var machine: AddressBarUIStateMachine

    public init(initialURLString: String) {
        self.machine = AddressBarUIStateMachine(initialURLString: initialURLString)
    }

    public init(snapshot: Snapshot) {
        self.machine = AddressBarUIStateMachine(snapshot: snapshot)
    }

    public func snapshot() -> Snapshot {
        machine.snapshot()
    }

    public mutating func restore(_ snapshot: Snapshot) {
        machine.restore(snapshot)
    }

    /// Reduce a UI-safe event into the deterministic state and effects.
    ///
    /// - Parameter state: authoritative UI state used by the view layer.
    /// - Returns: effects the app layer must execute (navigation/search/cancel).
    @discardableResult
    public mutating func reduce(
        state: inout AddressBarUIState,
        event: AddressBarEvent
    ) -> [AddressBarEffect] {
        // Keep the external `state` aligned with the machine at all times.
        // Callers must treat `state` as the rendered value and not mutate it directly.
        state = machine.state

        switch event {
        case .submitAndDismissEditing:
            var out: [AddressBarEffect] = []
            out.append(contentsOf: reduce(state: &state, event: .submit))
            _ = reduce(state: &state, event: .focusChanged(isFocused: false))
            return out

        case .cancelEditing:
            // Safari-like cancel intent.
            return reduce(state: &state, event: .tapOutside)

        case .submit:
            let submittedText: String = {
                switch machine.state {
                case .editing(let q): return q
                case .focused(let draft): return draft
                case .idle(let urlDisplayed, _): return urlDisplayed
                case .loading(_, let urlDisplayed, _): return urlDisplayed
                case .securityInfoDisplayed(let urlDisplayed, _): return urlDisplayed
                }
            }()

            machine.transition(.submit)
            state = machine.state

            let trimmed = submittedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return [] }

            switch classifySubmission(trimmed) {
            case .url:
                return [.openURLString(trimmed, force: false)]
            case .search:
                return [.search(trimmed)]
            case .empty:
                return []
            }

        case .tapOutside:
            machine.transition(.tapOutside)
            state = machine.state
            return [.cancel]

        default:
            machine.transition(event.asUXKitEvent)
            state = machine.state
            return []
        }
    }

    // MARK: - Submission classification
    public enum Submission: Sendable, Equatable {
        case empty
        case url
        case search
    }

    public static func classifySubmission(_ text: String) -> Submission {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return .empty }
        if looksLikeURL(trimmed) { return .url }
        return .search
    }

    private func classifySubmission(_ text: String) -> Submission {
        Self.classifySubmission(text)
    }

    private static func looksLikeURL(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.isEmpty == false else { return false }
        if t.contains(" ") { return false }
        if let url = URL(string: t), let scheme = url.scheme, scheme.isEmpty == false {
            return true
        }
        return t.contains(".")
    }
}

private extension AddressBarEvent {
    var asUXKitEvent: AddressBarUIEvent {
        switch self {
        case .tapAddressBar: return .tapAddressBar
        case .focusChanged(let isFocused): return .focusChanged(isFocused: isFocused)
        case .textChanged(let s): return .textChanged(s)
        case .navigationCommitted(let urlString): return .navigationCommitted(urlString: urlString)
        case .loadingChanged(let isLoading, let progress): return .loadingChanged(isLoading: isLoading, progress: progress)
        case .tapLockIcon: return .tapLockIcon
        case .dismissSecurityInfo: return .dismissSecurityInfo
        case .clearText: return .clearText
        case .tapOutside: return .tapOutside
        case .submit, .submitAndDismissEditing, .cancelEditing:
            // Handled explicitly by `AddressBarFeature.reduce`.
            return .tapOutside
        @unknown default:
            return .tapOutside
        }
    }
}
