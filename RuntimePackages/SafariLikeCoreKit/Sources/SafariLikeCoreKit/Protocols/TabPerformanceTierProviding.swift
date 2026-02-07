import Foundation

@MainActor
public protocol TabPerformanceTierProviding: AnyObject {
    var performanceTier: TabPriority { get set }
}
