import Foundation

public struct ChromeViewState: Equatable {
    public var isVisible: Bool
    public var isEditing: Bool
    public init(isVisible: Bool = true, isEditing: Bool = false) {
        self.isVisible = isVisible
        self.isEditing = isEditing
    }
}

public enum ChromeEvent {
    case appeared
    case disappeared
    case focusAddressBar
    case blurAddressBar
}
