import Foundation
import Combine
import SafariLikeCoreKit
internal enum StartPageState: Equatable {
    case idle
    case searching
    case overview
    case restoringSession
}
@MainActor
internal final class StartPageStateStore: ObservableObject {
    @Published private(set) var state: StartPageState = .idle
    @Published var query: String = ""
    func transition(to newState: StartPageState) {
        state = newState
    }
    func beginSearch() {
        transition(to: .searching)
    }
    func endSearch() {
        query = ""
        transition(to: .idle)
    }
}
