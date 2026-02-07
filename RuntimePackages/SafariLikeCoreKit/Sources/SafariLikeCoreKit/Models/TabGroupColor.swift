import Foundation

/// Semantic tab group colors shared across the stack.
///
/// CoreKit keeps this UI-agnostic; UI layers are
/// responsible for mapping these cases to concrete
/// colors (e.g. UIColor, SwiftUI.Color).
public enum TabGroupColor: String, CaseIterable, Codable, Sendable {
    case blue, red, green, orange, purple, gray
}
