import Foundation

@MainActor
public protocol ContentBlockingProviding: AnyObject {
    var enabledLists: [ContentBlockerList] { get }
    var isEnabled: Bool { get }
    var isReady: Bool { get }
    func setEnabled(_ enabled: Bool)
    func setListEnabled(_ list: ContentBlockerList, enabled: Bool)
    var onEnabledListsChanged: (([ContentBlockerList]) -> Void)? { get set }
}

public enum ContentBlockerList: String, CaseIterable, Sendable {
    case ads
    case trackers
    case social
    case privacy
}
