import SwiftUI
import Combine
import SafariLikeCoreKit
private struct IsLayoutStabilizingKey: EnvironmentKey {
    static let defaultValue: Bool = false
}
extension EnvironmentValues {
    /// True while container geometry is actively changing (e.g. during rotation).
    /// Use this to temporarily disable animations and defer expensive state updates.
    var isLayoutStabilizing: Bool {
        get { self[IsLayoutStabilizingKey.self] }
        set { self[IsLayoutStabilizingKey.self] = newValue }
    }
}
@MainActor
final class LayoutStabilizer: ObservableObject {
    @Published private(set) var isStabilizing: Bool = false
    /// Debounce window for "layout settled" after the last geometry change.
    private let settleDelayNanoseconds: UInt64
    private var settleTask: Task<Void, Never>?
    init(settleDelayNanoseconds: UInt64 = 140_000_000) {
        self.settleDelayNanoseconds = settleDelayNanoseconds
    }
    func markGeometryChanged() {
        isStabilizing = true
        settleTask?.cancel()
        settleTask = Task { [settleDelayNanoseconds] in
            do {
                try await Task.sleep(nanoseconds: settleDelayNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self.isStabilizing = false
        }
    }
}
