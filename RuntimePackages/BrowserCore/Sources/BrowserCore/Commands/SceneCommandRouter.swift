import Foundation
import SafariLikeContracts

/// Deterministic per-scene command router.
///
/// This router is pure: it takes a `CommandContextSnapshot` and emits an ordered list
/// of `CommandEffect`s. Execution is handled by the UI/runtime layer for the scene.
public struct SceneCommandRouter: Sendable {
    public init() {}

    public func route(_ command: AppCommand, in context: CommandContextSnapshot) -> CommandResolution {
        switch command {
        case .focusAddressBar:
            var effects: [CommandEffect] = []
            if context.isTabOverviewVisible {
                effects.append(.setTabOverviewVisible(false))
            }
            effects.append(.focusAddressBar(selectAll: true))
            return .init(isHandled: true, effects: effects)

        case .newTab:
            var effects: [CommandEffect] = []
            if context.isTabOverviewVisible {
                effects.append(.setTabOverviewVisible(false))
            }
            effects.append(.newTab(inBackground: false))
            return .init(isHandled: true, effects: effects)

        case .close:
            if context.isTabOverviewVisible, let id = context.tabOverviewSelectedTabID {
                return .init(isHandled: true, effects: [.closeTab(id: id)])
            }
            if let id = context.activeTabID {
                return .init(isHandled: true, effects: [.closeTab(id: id)])
            }
            return .unhandled

        case .reopenLastClosedTab:
            guard context.hasRecentlyClosedTabs else { return .unhandled }
            return .init(isHandled: true, effects: [.reopenLastClosedTab])

        case .reload:
            return .init(isHandled: true, effects: [.reload])

        case .goBack:
            return .init(isHandled: true, effects: [.goBack])

        case .goForward:
            return .init(isHandled: true, effects: [.goForward])

        case .showFindOnPage:
            return .init(isHandled: true, effects: [.presentFindOnPage])

        case .showSettings:
            return .init(isHandled: true, effects: [.presentSettings])

        case let .selectTabByNumber(number):
            guard context.tabCount > 0 else { return .unhandled }
            return .init(isHandled: true, effects: [.selectTabByNumber(number)])

        case .selectNextTab:
            guard context.tabCount > 1 else { return .unhandled }
            return .init(isHandled: true, effects: [.selectNextTab])

        case .selectPreviousTab:
            guard context.tabCount > 1 else { return .unhandled }
            return .init(isHandled: true, effects: [.selectPreviousTab])

        case .toggleTabOverview:
            return .init(isHandled: true, effects: [.setTabOverviewVisible(!context.isTabOverviewVisible)])

        @unknown default:
            return .unhandled
        }
    }
}
