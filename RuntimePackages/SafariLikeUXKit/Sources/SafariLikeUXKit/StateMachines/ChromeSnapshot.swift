import CoreGraphics

/// Immutable value snapshot of the current chrome state.
///
/// Must remain a pure value type (no reference storage, no closures).
public struct ChromeSnapshot: Equatable, Sendable {
    public let state: ChromeStateMachine.State

    public var isCollapsed: Bool { state == .collapsed }
    public var isEditing: Bool { state == .editing }
    public var isInOverview: Bool { state == .overview }
    public var isOmniboxOverlayVisible: Bool { state == .editing }
    public var isAddressFocused: Bool { state == .editing }

    public init(state: ChromeStateMachine.State) {
        self.state = state
    }
}
