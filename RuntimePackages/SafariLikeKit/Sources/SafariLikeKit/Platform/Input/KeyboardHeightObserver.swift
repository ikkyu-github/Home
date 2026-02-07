import SwiftUI
import Combine
import UIKit
import SafariLikeCoreKit
/// Observes the current keyboard height (in screen coordinates) and publishes changes.
///
/// This is used to keep the Safari-like bottom toolbar (address bar) positioned
/// above the keyboard in portrait when editing, without relying on WKWebView responder hacks.
@MainActor
final class KeyboardHeightObserver: ObservableObject {
    @Published private(set) var height: CGFloat = 0
    private var cancellables = Set<AnyCancellable>()
    init() {
        let center = NotificationCenter.default
        let willChange = center.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
        let willHide = center.publisher(for: UIResponder.keyboardWillHideNotification)
        willChange
            .merge(with: willHide)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                self?.handle(note)
            }
            .store(in: &cancellables)
    }
    private func handle(_ note: Notification) {
        guard let info = note.userInfo else { return }
        if note.name == UIResponder.keyboardWillHideNotification {
            height = 0
            return
        }
        guard let endFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let allWindows: [UIWindow] = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        guard let window = allWindows.first(where: { $0.isKeyWindow }) ?? allWindows.first else { return }
        let endInWindow = window.convert(endFrame, from: nil)
        let intersection = window.bounds.intersection(endInWindow)
        height = max(0, intersection.height)
    }
}
