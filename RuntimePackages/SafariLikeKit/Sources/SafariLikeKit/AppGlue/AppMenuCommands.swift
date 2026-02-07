import SwiftUI
import SafariLikeCoreKit
struct AppMenuCommands: Commands {
    public init() {}
    public var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                Task { @MainActor in
                    AppWindowActions.openNewWindowIfSupported()
                }            }
            .keyboardShortcut("n", modifiers: [.command])
        }
    }
}