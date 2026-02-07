import SwiftUI
import SafariLikeContracts

/// SwiftUI Commands providing Safari-like keyboard shortcuts.
///
/// Routing is scene-local via `@FocusedSceneValue`.
public struct SafariLikeBrowserCommands: Commands {
    @FocusedValue(\.safariLikeSceneCommandHandler) private var handler

    public init() {}

    private func send(_ command: AppCommand) {
        handler?(command)
    }

    public var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                Task { @MainActor in
                    AppWindowActions.openNewWindowIfSupported()
                }
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("New Tab") { send(.newTab) }
                .keyboardShortcut("t", modifiers: [.command])
        }

        CommandMenu("Navigation") {
            Button("Back") { send(.goBack) }
                .keyboardShortcut("[", modifiers: [.command])

            Button("Forward") { send(.goForward) }
                .keyboardShortcut("]", modifiers: [.command])

            Button("Reload") { send(.reload) }
                .keyboardShortcut("r", modifiers: [.command])
        }

        CommandMenu("Tab") {
            Button("Close Tab") { send(.close) }
                .keyboardShortcut("w", modifiers: [.command])

            Button("Reopen Closed Tab") { send(.reopenLastClosedTab) }
                .keyboardShortcut("t", modifiers: [.command, .shift])

            Divider()

            Button("Show Tab Overview") { send(.toggleTabOverview) }
                .keyboardShortcut("\\", modifiers: [.command, .shift])

            Divider()

            Button("Select Tab 1") { send(.selectTabByNumber(1)) }.keyboardShortcut("1", modifiers: [.command])
            Button("Select Tab 2") { send(.selectTabByNumber(2)) }.keyboardShortcut("2", modifiers: [.command])
            Button("Select Tab 3") { send(.selectTabByNumber(3)) }.keyboardShortcut("3", modifiers: [.command])
            Button("Select Tab 4") { send(.selectTabByNumber(4)) }.keyboardShortcut("4", modifiers: [.command])
            Button("Select Tab 5") { send(.selectTabByNumber(5)) }.keyboardShortcut("5", modifiers: [.command])
            Button("Select Tab 6") { send(.selectTabByNumber(6)) }.keyboardShortcut("6", modifiers: [.command])
            Button("Select Tab 7") { send(.selectTabByNumber(7)) }.keyboardShortcut("7", modifiers: [.command])
            Button("Select Tab 8") { send(.selectTabByNumber(8)) }.keyboardShortcut("8", modifiers: [.command])
            Button("Select Last Tab") { send(.selectTabByNumber(9)) }.keyboardShortcut("9", modifiers: [.command])

            Divider()

            Button("Next Tab") { send(.selectNextTab) }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])

            Button("Previous Tab") { send(.selectPreviousTab) }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
        }

        CommandMenu("Tools") {
            Button("Focus Address Bar") { send(.focusAddressBar) }
                .keyboardShortcut("l", modifiers: [.command])

            Button("Find on Page") { send(.showFindOnPage) }
                .keyboardShortcut("f", modifiers: [.command])

            Button("Settings") { send(.showSettings) }
                .keyboardShortcut(",", modifiers: [.command])
        }
    }
}
