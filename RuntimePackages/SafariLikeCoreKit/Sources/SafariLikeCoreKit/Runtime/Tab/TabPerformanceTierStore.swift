import Foundation

@MainActor
public final class TabPerformanceTierStore: TabPerformanceTierProviding {
    public var performanceTier: TabPriority

    public init(performanceTier: TabPriority = .foreground) {
        self.performanceTier = performanceTier
    }
}
