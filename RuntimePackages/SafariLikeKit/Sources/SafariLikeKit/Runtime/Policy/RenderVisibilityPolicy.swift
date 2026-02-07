import Foundation
import SafariLikeCoreKit

/// Pure, deterministic render + visibility policy.
///
/// Responsibilities:
/// - Decide which tabs should keep a live WKWebView within the render budget.
/// - Decide UI-facing render modes (active/preview/frozen/discarded) deterministically.
/// - Decide per-tab WebView performance tiers based on visibility + active status.
///
/// This type must remain side-effect free. Application of the decision is owned by the
/// SafariLikeKit runtime single-writer (TabManager).
struct RenderVisibilityPolicy {
    struct Input {
        let isSplitPresented: Bool
        let isTabOverviewVisible: Bool
        let activePane: BrowserCore.RenderBudgetPolicy.ActivePane
        let activeTabID: UUID?
        let leftTabID: UUID?
        let rightTabID: UUID?
        let bindingTabID: UUID?
        let visibleTabIDs: Set<UUID>

        let sessionTabs: [BrowserTab]
        let tabStates: [TabState]
        let aliveTabIDs: [UUID]
    }

    struct Decision: Equatable {
        let keepRendered: [UUID]
        let keepSet: Set<UUID>
        let renderModeByTabID: [UUID: TabRenderMode]
        let performanceTierByTabID: [UUID: WebViewPerformanceTier]

        var summary: String {
            let keep = keepRendered.prefix(4).map { $0.uuidString }.joined(separator: ",")
            return "keep=\(keepRendered.count)[\(keep)] tiers=\(performanceTierByTabID.count)"
        }
    }

    static func decide(input: Input) -> Decision {
        // 1) Render budget (pure): compute which *web* tabs should keep a live WebView.
        let isWebTab: (UUID) -> Bool = { id in
            guard let tab = input.sessionTabs.first(where: { $0.id == id }) else { return false }
            if case .web = tab.state { return true }
            return false
        }

        let activePaneTabID: UUID? = {
            guard input.isSplitPresented else { return input.activeTabID }
            switch input.activePane {
            case .right:
                return input.rightTabID ?? input.activeTabID
            case .left:
                return input.leftTabID ?? input.activeTabID
            @unknown default:
                return input.activeTabID
            }
        }()

        let previewTabID: UUID? = {
            guard input.isSplitPresented else {
                guard let binding = input.bindingTabID, binding != activePaneTabID else { return nil }
                return binding
            }
            let other: UUID? = (input.activePane == .right) ? input.leftTabID : input.rightTabID
            guard other != activePaneTabID else { return nil }
            return other
        }()

        let budgetInput = BrowserCore.RenderBudgetPolicy.Input(
            isSplitEnabled: input.isSplitPresented,
            isTabOverviewVisible: input.isTabOverviewVisible,
            activePane: input.activePane,
            activeTabID: input.activeTabID,
            leftTabID: input.leftTabID,
            rightTabID: input.rightTabID,
            bindingTabID: (input.bindingTabID.flatMap { isWebTab($0) ? $0 : nil })
        )

        let aliveWebCandidates = input.aliveTabIDs.filter(isWebTab)
        let budgetDecision = BrowserCore.RenderBudgetPolicy.decide(input: budgetInput, candidates: aliveWebCandidates)
        let desiredLiveTabIDs = budgetDecision.keepRendered
        let keepSet = Set(desiredLiveTabIDs).intersection(input.aliveTabIDs)

        // 2) UI-facing render mode mapping (pure).
        var renderModeByTabID: [UUID: TabRenderMode] = [:]
        for s in input.tabStates {
            let id = s.id
            if s.lifecycle == .discarded || s.lifecycle == .closed {
                renderModeByTabID[id] = .discarded
                continue
            }
            if id == activePaneTabID, keepSet.contains(id) {
                renderModeByTabID[id] = .active
            } else if id == previewTabID, keepSet.contains(id) {
                renderModeByTabID[id] = .preview
            } else {
                renderModeByTabID[id] = .frozen
            }
        }

        var performanceTierByTabID: [UUID: WebViewPerformanceTier] = [:]
        for tab in input.sessionTabs {
            let tabID = tab.id
            let tier: WebViewPerformanceTier
            if input.activeTabID == tabID {
                tier = .foreground
            } else if input.visibleTabIDs.contains(tabID) {
                tier = .backgroundVisible
            } else {
                tier = .backgroundHidden
            }
            performanceTierByTabID[tabID] = tier
        }

        return Decision(
            keepRendered: desiredLiveTabIDs,
            keepSet: keepSet,
            renderModeByTabID: renderModeByTabID,
            performanceTierByTabID: performanceTierByTabID
        )
    }
}
