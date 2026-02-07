import Foundation

/// Canonical tab lifecycle state.
///
/// Compatibility:
/// - Older persisted values (e.g. `creating`, `restoring`, `background`) are mapped into
///   the canonical state machine on decode.
public enum TabLifecycleState: String, Codable, Sendable, Equatable {
    case cold
    case warming
    case active
    case suspended
    case discarded
    case closed

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? "cold"

        switch raw {
        case "cold":
            self = .cold
        case "warming":
            self = .warming
        case "active":
            self = .active
        case "suspended":
            self = .suspended
        case "discarded":
            self = .discarded
        case "closed":
            self = .closed

        // Legacy values
        case "creating":
            self = .cold
        case "restoring":
            self = .warming
        case "background":
            self = .suspended

        default:
            self = .cold
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// User-facing lifecycle phase.
    ///
    /// This intentionally matches the vocabulary used at the app/UI layer:
    /// - `created` (no WebView yet)
    /// - `restoring` (warming up after discard)
    /// - `active` (foreground + interactive)
    /// - `background` (kept but not actively rendering)
    /// - `discarded` (WebView destroyed; snapshot/token may exist)
    ///
    /// Note: `.closed` is a terminal canonical state and maps to `.discarded` here.
    public enum Phase: String, Codable, Sendable, Equatable {
        case created
        case restoring
        case active
        case background
        case discarded
    }

    public var phase: Phase {
        switch self {
        case .cold:
            return .created
        case .warming:
            return .restoring
        case .active:
            return .active
        case .suspended:
            return .background
        case .discarded, .closed:
            return .discarded
        }
    }

    public init(phase: Phase) {
        switch phase {
        case .created:
            self = .cold
        case .restoring:
            self = .warming
        case .active:
            self = .active
        case .background:
            self = .suspended
        case .discarded:
            self = .discarded
        }
    }
}
