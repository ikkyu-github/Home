import Foundation

/// Safari-like navigation policy configuration applied per-navigation.
///
/// - Important: This is a pure-data configuration object. Evaluation is done by
///   `SafariNavigationPolicyEvaluator` as a pure function.
public struct NavigationPolicy: Sendable, Equatable, Codable {
    public var allowPopups: Bool
    public var allowAutoplay: Bool
    public var allowCrossSiteTracking: Bool
    public var contentBlockerEnabled: Bool
    public var privateMode: Bool

    public init(
        allowPopups: Bool,
        allowAutoplay: Bool,
        allowCrossSiteTracking: Bool,
        contentBlockerEnabled: Bool,
        privateMode: Bool
    ) {
        self.allowPopups = allowPopups
        self.allowAutoplay = allowAutoplay
        self.allowCrossSiteTracking = allowCrossSiteTracking
        self.contentBlockerEnabled = contentBlockerEnabled
        self.privateMode = privateMode
    }
}

public enum NavigationDecisionPoint: String, Sendable, Codable {
    case beforeNavigation
    case afterResponse
    case redirect
    case newWindow
}

public enum NavigationPolicyOutcome: String, Sendable, Codable {
    case allow
    case cancel
    case openInNewTab
    case openInNewWindow
}

public struct NavigationPolicyInput: Sendable, Equatable, Codable {
    public var point: NavigationDecisionPoint

    public var urlString: String
    public var scheme: String

    public var isMainFrame: Bool
    public var navigationType: NavigationType

    /// When WebKit indicates a new-window request (e.g. targetFrame == nil).
    public var isNewWindowRequest: Bool

    /// Redirect chain information, if applicable.
    public var redirectDepth: Int
    public var isRedirectCycle: Bool

    /// Best-effort mime type for responses.
    public var mimeType: String?

    public init(
        point: NavigationDecisionPoint,
        urlString: String,
        scheme: String,
        isMainFrame: Bool,
        navigationType: NavigationType,
        isNewWindowRequest: Bool,
        redirectDepth: Int,
        isRedirectCycle: Bool,
        mimeType: String?
    ) {
        self.point = point
        self.urlString = urlString
        self.scheme = scheme
        self.isMainFrame = isMainFrame
        self.navigationType = navigationType
        self.isNewWindowRequest = isNewWindowRequest
        self.redirectDepth = redirectDepth
        self.isRedirectCycle = isRedirectCycle
        self.mimeType = mimeType
    }
}

public struct NavigationPolicyDecision: Sendable, Equatable, Codable {
    public var point: NavigationDecisionPoint
    public var outcome: NavigationPolicyOutcome
    public var reason: String?

    /// Echo the effective policy used for the decision.
    public var policy: NavigationPolicy

    /// Echo the input used for the decision.
    public var input: NavigationPolicyInput

    public init(
        point: NavigationDecisionPoint,
        outcome: NavigationPolicyOutcome,
        reason: String?,
        policy: NavigationPolicy,
        input: NavigationPolicyInput
    ) {
        self.point = point
        self.outcome = outcome
        self.reason = reason
        self.policy = policy
        self.input = input
    }
}

public enum SafariNavigationPolicyEvaluator {

    /// Pure function: (policy,input) -> decision.
    public static func evaluate(policy: NavigationPolicy, input: NavigationPolicyInput) -> NavigationPolicyDecision {
        switch input.point {
        case .beforeNavigation:
            // Scheme gate: only allow web-like schemes in the WebView.
            // Note: core PolicyCenter rules may still cancel/upgrade; this is the Safari UX layer.
            switch input.scheme {
            case "http", "https", "about":
                return .init(point: input.point, outcome: .allow, reason: nil, policy: policy, input: input)
            case "file":
                // Allowing file URLs is controlled by the core PolicyProviding layer.
                return .init(point: input.point, outcome: .allow, reason: nil, policy: policy, input: input)
            case "mailto", "tel", "itms-apps":
                return .init(point: input.point, outcome: .cancel, reason: "external_scheme", policy: policy, input: input)
            default:
                return .init(point: input.point, outcome: .cancel, reason: "unsupported_scheme", policy: policy, input: input)
            }

        case .afterResponse:
            // Reader eligibility and content rules are applied by higher layers; this stage logs
            // the decision inputs deterministically.
            return .init(point: input.point, outcome: .allow, reason: nil, policy: policy, input: input)

        case .redirect:
            if input.isRedirectCycle {
                return .init(point: input.point, outcome: .cancel, reason: "redirect_cycle", policy: policy, input: input)
            }
            // Safari-like safety cap.
            if input.redirectDepth > 10 {
                return .init(point: input.point, outcome: .cancel, reason: "redirect_too_many_hops", policy: policy, input: input)
            }
            return .init(point: input.point, outcome: .allow, reason: nil, policy: policy, input: input)

        case .newWindow:
            guard input.isNewWindowRequest else {
                return .init(point: input.point, outcome: .allow, reason: nil, policy: policy, input: input)
            }
            guard policy.allowPopups else {
                return .init(point: input.point, outcome: .cancel, reason: "popups_blocked", policy: policy, input: input)
            }
            // Default: open in a new tab (Safari-like on iPhone; iPad may use a new window
            // but that choice is owned by higher UI/scene layers).
            return .init(point: input.point, outcome: .openInNewTab, reason: nil, policy: policy, input: input)
        }
    }
}
