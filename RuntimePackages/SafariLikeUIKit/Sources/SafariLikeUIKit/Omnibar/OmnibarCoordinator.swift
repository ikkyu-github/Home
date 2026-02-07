import Foundation
import Combine
import SafariLikeKit

@MainActor
public final class OmnibarCoordinator: ObservableObject {
    @Published public private(set) var state: OmnibarState

    private var machine: OmnibarStateMachine

    /// Window-scoped navigation handler injected by the host (per scene/window).
    ///
    /// This avoids using a global navigation router that can be overwritten when multiple
    /// windows/scenes are active.
    public var onNavigate: (@MainActor (URL) -> Void)?

    public init(initial: OmnibarState = .collapsed(showURL: true)) {
        self.machine = OmnibarStateMachine(initial: initial)
        self.state = initial
    }

    public func send(_ event: OmnibarEvent) {
        machine.handle(event)
        state = machine.state
    }

    public func submit(_ text: String) {
        send(.onSubmit(text: text))
        switch machine.state {
        case .navigating(let url):
            onNavigate?(url)
        default:
            break
        }
    }

    public func cancelEditing() {
        send(.onCancel)
    }

    public func openSuggestions() {
        switch state {
        case .focused(let text, _):
            send(.onTextChange(text: text))
        default:
            break
        }
    }

    public func pasteAndGo(_ text: String) {
        send(.onBeginEditing(text: text))
        submit(text)
    }
}
