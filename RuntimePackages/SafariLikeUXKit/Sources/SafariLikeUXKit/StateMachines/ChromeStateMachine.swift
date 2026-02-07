import CoreGraphics

/// Pure state machine for Safari-like chrome behavior.
///
/// - No side effects
/// - No async work
/// - No WebKit references
public struct ChromeStateMachine: Sendable {

    public enum State: Equatable, Sendable {
        case expanded
        case collapsed
        case editing
        case overview
    }

    public enum Event: Equatable, Sendable {
        /// Address bar focus changed (e.g. TextField focus).
        case focusChanged(Bool)
        /// Scroll update from the active web content.
        /// - Parameters:
        ///   - y: contentOffset.y
        ///   - velocityY: points/second-ish (runtime-defined)
        case scroll(y: CGFloat, velocityY: CGFloat)
        /// Tab overview visibility toggled.
        case overviewToggled(Bool)
        /// Address bar commit (Go / submit).
        case commit
        /// Address bar cancel (dismiss editing).
        case cancel
    }

    public struct Configuration: Sendable {
        public var collapseThreshold: CGFloat
        public var expandThreshold: CGFloat

        public init(
            collapseThreshold: CGFloat = 18,
            expandThreshold: CGFloat = 10
        ) {
            self.collapseThreshold = collapseThreshold
            self.expandThreshold = expandThreshold
        }
    }

    public private(set) var config: Configuration
    private var state: State

    /// Internal scroll history used to compute deltas in a pure way.
    private var lastScrollY: CGFloat

    public init(
        initialState: State = .expanded,
        config: Configuration = .init(),
        initialScrollY: CGFloat = 0
    ) {
        self.state = initialState
        self.config = config
        self.lastScrollY = initialScrollY
    }

    /// Current snapshot (value copy).
    public func snapshot() -> ChromeSnapshot {
        ChromeSnapshot(state: state)
    }

    /// Pure reducer entrypoint.
    ///
    /// - Important: callers must use the returned snapshot and must not read machine internals.
    @discardableResult
    public mutating func reduce(_ event: Event) -> ChromeSnapshot {
        let previousState = state
        let nextState = transition(event)
        if nextState == previousState {
            return ChromeSnapshot(state: previousState)
        }
        return ChromeSnapshot(state: nextState)
    }

    /// Apply an event and return the new state.
    ///
    /// This method is intentionally side-effect free.
    @discardableResult
    private mutating func transition(_ event: Event) -> State {
        switch event {
        case .focusChanged(let focused):
            if focused {
                state = .editing
            } else {
                // Leaving editing always expands the chrome.
                if state == .editing {
                    state = .expanded
                }
            }
            return state

        case .overviewToggled(let visible):
            state = visible ? .overview : .expanded
            return state

        case .commit, .cancel:
            state = .expanded
            return state

        case .scroll(let y, _):
            let delta = y - lastScrollY
            lastScrollY = y

            // Never collapse while editing or in overview.
            if state == .editing || state == .overview {
                return state
            }

            // Pulling down / top of page should expand.
            if y <= 0 {
                state = .expanded
                return state
            }

            if delta > config.collapseThreshold {
                state = .collapsed
            } else if delta < -config.expandThreshold {
                state = .expanded
            }
            return state
        }
    }
}
