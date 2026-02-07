import Foundation

/// Window-level sidebar presentation state.
///
/// This is a pure domain model (UI observes it; UI does not own it).
public enum SidebarMode: Sendable, Equatable {
    case hidden
    case visible(content: SidebarContent)
}

/// Canonical sidebar destinations.
public enum SidebarContent: Sendable, Equatable {
    case menu
    case bookmarks
    case readingList
    case history
}
