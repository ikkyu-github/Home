import SwiftUI
import Combine

@MainActor
final class AppSettingsStore: ObservableObject {

    @Published var colorScheme: ColorScheme? = nil
    @Published var isDarkModeEnabled: Bool = false

    init() {}

    func applyAppearance(_ enabled: Bool) {
        isDarkModeEnabled = enabled
        colorScheme = enabled ? .dark : .light
    }
}
