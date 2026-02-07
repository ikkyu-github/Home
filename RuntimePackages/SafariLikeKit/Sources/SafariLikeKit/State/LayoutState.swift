import Foundation
import CoreGraphics
import Combine
import SafariLikeCoreKit
@MainActor
public final class LayoutState: ObservableObject {
    @Published var splitRatio: CGFloat = 0.5
    @Published var activePane: TabManager.ActivePane = .left
    @Published var isSidebarVisible: Bool = false
}
