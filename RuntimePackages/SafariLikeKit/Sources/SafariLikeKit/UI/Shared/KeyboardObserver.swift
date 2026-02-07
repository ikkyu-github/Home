import SwiftUI
import Combine
import SafariLikeCoreKit
final class KeyboardObserver: ObservableObject {
    @Published var height: CGFloat = 0
    private var cancellables = Set<AnyCancellable>()
    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .compactMap { $0.userInfo }
            .sink { [weak self] info in
                guard
                    let frame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                    let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
                    let curveRaw = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
                else { return }
                let screenHeight = UIScreen.main.bounds.height
                let keyboardHeight = max(0, screenHeight - frame.origin.y)
                withAnimation(.timingCurve(
                    CGFloat((curveRaw >> 16) & 0xff),
                    0, 0, 1,
                    duration: duration
                )) {
                    self?.height = keyboardHeight
                }
            }
            .store(in: &cancellables)
    }
}
