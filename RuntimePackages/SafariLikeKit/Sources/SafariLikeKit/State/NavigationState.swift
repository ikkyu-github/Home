import Foundation
import Combine
import SafariLikeCoreKit
@MainActor
public final class NavigationState: ObservableObject {
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isLoading: Bool = false
}
