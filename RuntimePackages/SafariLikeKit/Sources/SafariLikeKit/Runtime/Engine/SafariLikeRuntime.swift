import SafariLikeCoreKit
@MainActor
public enum SafariLikeRuntime {
    private nonisolated(unsafe) static var didConfigureEngine: Bool = false
    public static func configureEngineIfNeeded() {
        guard didConfigureEngine == false else { return }
        EngineController.configureShared(memoryPressureSource: UIKitMemoryPressureSource())
        didConfigureEngine = true
    }
}
