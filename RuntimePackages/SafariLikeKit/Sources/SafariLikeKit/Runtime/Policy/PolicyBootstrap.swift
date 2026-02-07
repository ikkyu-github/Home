import Foundation
import SafariLikeCoreKit
@MainActor
public enum PolicyBootstrap {
    private static var didInstall = false
    private static var tracerToken: UUID?
    public static func installIfNeeded() {
        guard didInstall == false else { return }
        didInstall = true
        Task { @MainActor in
            await PolicyCenter.shared.register(NavigationPolicy())
            await PolicyCenter.shared.register(ResourcePolicy())
            await PolicyCenter.shared.register(PrivacyPolicy())
            tracerToken = await PolicyCenter.shared.addObserver { event in
                let prefix: String
                switch event.domain {
                case .navigation: prefix = "policy.navigation"
                case .resource: prefix = "policy.resource"
                case .privacy: prefix = "policy.privacy"
                @unknown default: prefix = "policy.unknown"
                }
                switch event.decision {
                case .allow:
                    LaunchTracer.shared.mark(prefix + ".allow")
                case .cancel(let reason):
                    LaunchTracer.shared.mark(prefix + ".cancel", "reason=\(reason)")
                case .modify:
                    LaunchTracer.shared.mark(prefix + ".modify")
                @unknown default:
                    LaunchTracer.shared.mark(prefix + ".unknown")
                }
            }
        }
    }
}
