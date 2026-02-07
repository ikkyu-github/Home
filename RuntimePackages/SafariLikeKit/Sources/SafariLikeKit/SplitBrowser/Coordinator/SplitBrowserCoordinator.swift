import Foundation
import SafariLikeCoreKit
/// Coordinator that updates state and triggers side-effects.
/// Fully @MainActor isolated - all operations execute on the main thread.
@MainActor
final class SplitBrowserCoordinator {
    private let tabService: TabService
    private let navigationService: NavigationService
    /// Initialize coordinator with injected services.
    /// - Parameters:
    ///   - tabService: Service for tab management operations (required)
    ///   - navigationService: Service for navigation operations (required)
    public init(
        tabService: TabService,
        navigationService: NavigationService
    ) {
        self.tabService = tabService
        self.navigationService = navigationService
    }
    /// Dispatch and handle high-level split browser actions.
    /// - Parameters:
    ///   - action: The action to execute
    ///   - viewModel: The view model to update
    func dispatch(_ action: SplitBrowserAction, in viewModel: SplitBrowserViewModel) {
        switch action {
        case .browser(let a):
            viewModel.send(a)
        case .toggleSidebar:
            viewModel.toggleSidebar()
            // `SplitBrowserViewModel` updates Published; state mirrors via sinks
        case .showTabOverview(let show):
            if show { viewModel.presentTabOverview() } else { viewModel.dismissTabOverview() }
        case .toggleCompanion:
            viewModel.toggleCompanion()
        case .setSplitEnabled(let enabled):
            tabService.setSplitEnabled(enabled, in: viewModel)
        }
    }
}
