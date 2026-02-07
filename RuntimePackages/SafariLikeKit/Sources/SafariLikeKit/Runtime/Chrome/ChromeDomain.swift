import Foundation
import Combine

public final class ChromeDomain: ObservableObject {
    @Published public private(set) var state: ChromeViewState

    public init(initialState: ChromeViewState = .init()) {
        self.state = initialState
    }

    public func dispatch(_ event: ChromeEvent) {
        // State machine logic: update state based on event
        // (no-op for now)
    }
}
