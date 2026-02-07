import Foundation

/// Pure decision policy for keeping live-rendered WebViews within a strict budget.
///
/// Goals (Safari-like):
/// - Split OFF  -> at most 1 live-rendered WebView
/// - Split ON   -> at most 2 live-rendered WebViews (typically left + right)
///
/// This policy does not touch WebKit; it only returns a decision.
public enum RenderBudgetPolicy {

    public enum ActivePane: Sendable {
        case left
        case right
    }

    public struct Input: Sendable {
        public let isSplitEnabled: Bool
        public let isTabOverviewVisible: Bool
        public let activePane: ActivePane

        public let activeTabID: UUID?
        public let leftTabID: UUID?
        public let rightTabID: UUID?
        public let bindingTabID: UUID?

        public init(
            isSplitEnabled: Bool,
            isTabOverviewVisible: Bool,
            activePane: ActivePane,
            activeTabID: UUID?,
            leftTabID: UUID?,
            rightTabID: UUID?,
            bindingTabID: UUID?
        ) {
            self.isSplitEnabled = isSplitEnabled
            self.isTabOverviewVisible = isTabOverviewVisible
            self.activePane = activePane
            self.activeTabID = activeTabID
            self.leftTabID = leftTabID
            self.rightTabID = rightTabID
            self.bindingTabID = bindingTabID
        }
    }

    public struct Decision: Sendable {
        /// Tabs that should keep a live-rendered web view attached.
        public let keepRendered: [UUID]
        /// Tabs that should be frozen/snapshot-only (detach web view).
        public let freeze: Set<UUID>
        /// Tabs that may be evicted more aggressively (destroy runtime / invalidate store).
        public let evict: Set<UUID>

        public init(keepRendered: [UUID], freeze: Set<UUID>, evict: Set<UUID>) {
            self.keepRendered = keepRendered
            self.freeze = freeze
            self.evict = evict
        }
    }

    public static func decide(
        input: Input,
        candidates: [UUID]
    ) -> Decision {
        // Safari behavior: entering tab overview freezes ALL webviews (snapshots only).
        let maxRendered = input.isTabOverviewVisible ? 0 : (input.isSplitEnabled ? 2 : 1)

        var ordered: [UUID] = []
        func push(_ id: UUID?) {
            guard let id else { return }
            if ordered.contains(id) { return }
            ordered.append(id)
        }

        // Highest priority: whatever is currently being bound/bound.
        push(input.bindingTabID)

        if input.isSplitEnabled {
            // Favor the active pane, then the other visible pane.
            switch input.activePane {
            case .left:
                push(input.leftTabID)
                push(input.rightTabID)
            case .right:
                push(input.rightTabID)
                push(input.leftTabID)
            }

            // Fallbacks.
            push(input.activeTabID)
        } else {
            // Single-pane: prefer the active tab.
            push(input.activeTabID)
            push(input.leftTabID)
            push(input.rightTabID)
        }

        // Final fallback to any alive candidate.
        if let first = candidates.first {
            push(first)
        }

        let keep = Array(ordered.prefix(maxRendered))
        let keepSet = Set(keep)
        let freeze = Set(candidates).subtracting(keepSet)

        return Decision(keepRendered: keep, freeze: freeze, evict: [])
    }
}
