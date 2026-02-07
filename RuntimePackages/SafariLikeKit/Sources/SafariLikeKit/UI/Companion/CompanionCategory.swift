import SafariLikeCoreKit
// Source of truth for CompanionCategory
// No dependency on PanePolicy or ViewModel
internal enum CompanionCategory: String, CaseIterable {
    case related
    case bookmarks
    case history
    case settings
}
