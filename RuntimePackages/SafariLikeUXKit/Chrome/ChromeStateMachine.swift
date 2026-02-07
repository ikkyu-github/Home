import Foundation
import Combine

// MARK: - ChromeEvent
public enum ChromeEvent {
    case tapBack
    case tapForward
    case tapReload
    case tapShare
    case tapTab
    case tapMenu
    // Add more events as needed
}

// MARK: - ChromeViewState
public struct ChromeViewState {
    public var canGoBack: Bool
    public var canGoForward: Bool
    public var isLoading: Bool
    public var showMenu: Bool
    // Add more state as needed

    public init(canGoBack: Bool = false, canGoForward: Bool = false, isLoading: Bool = false, showMenu: Bool = false) {
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.isLoading = isLoading
        self.showMenu = showMenu
    }
}

// MARK: - ChromeEventRouter
public final class ChromeEventRouter: ObservableObject {
    @Published var viewState: ChromeViewState
    private let eventSubject = PassthroughSubject<ChromeEvent, Never>()
    private var cancellables = Set<AnyCancellable>()

    public init(initialState: ChromeViewState = ChromeViewState()) {
        self.viewState = initialState
    }

    public func dispatch(_ event: ChromeEvent) {
        eventSubject.send(event)
        // Route event to state machine
        // ...state machine logic here...
    }

    public func subscribe(_ handler: @escaping (ChromeEvent) -> Void) {
        eventSubject.sink(receiveValue: handler).store(in: &cancellables)
    }
}
