import Foundation

@MainActor
public protocol TabRestoreStateProviding: AnyObject {
    var restoreState: TabRestoreState? { get }
}

@MainActor
public protocol TabRestoreStateUpdating: AnyObject {
    func updateRestoreState(currentURL: URL?, lastKnownTitle: String?)
}

public typealias TabRestoreStateStoring = TabRestoreStateProviding & TabRestoreStateUpdating
