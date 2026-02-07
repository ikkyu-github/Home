import Foundation

/// A router output: a deterministic list of scene-local effects.
public struct CommandResolution: Codable, Sendable, Hashable {
    public var isHandled: Bool
    public var effects: [CommandEffect]

    public init(isHandled: Bool, effects: [CommandEffect]) {
        self.isHandled = isHandled
        self.effects = effects
    }

    public static let unhandled = CommandResolution(isHandled: false, effects: [])
}

/// Scene-local effects that a UI layer can execute.
///
/// These are intentionally high-level and deterministic.
public enum CommandEffect: Codable, Sendable, Hashable {
    case focusAddressBar(selectAll: Bool)

    case presentFindOnPage
    case presentSettings

    case setTabOverviewVisible(Bool)

    case newTab(inBackground: Bool)

    /// Close a specific tab (scene-local ID).
    case closeTab(id: UUID)

    case reopenLastClosedTab

    case reload
    case goBack
    case goForward

    /// Safari-style number row semantics.
    /// - 1 selects the first tab.
    /// - 9 selects the last tab.
    case selectTabByNumber(Int)

    case selectNextTab
    case selectPreviousTab
}
