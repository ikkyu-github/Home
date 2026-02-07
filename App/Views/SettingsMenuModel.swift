import Foundation
import Combine

@MainActor
final class SettingsMenuModel: ObservableObject {

    enum SettingsSection: Hashable, Identifiable {
        case appearance
        case language
        case privacy
        case search
        case diagnostics
        case performance
        case plugins

        var id: Self { self }
    }

    enum SettingsDestination: Hashable {
        case performance
		case networkDiagnostics
    }

    @Published var path: [SettingsDestination] = []

    func navigate(to destination: SettingsDestination) {
        path.append(destination)
    }
}
