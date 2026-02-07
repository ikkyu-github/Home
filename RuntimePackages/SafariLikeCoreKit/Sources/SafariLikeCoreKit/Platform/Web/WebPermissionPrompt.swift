import Foundation

public enum WebPermissionKind: String, Codable, Hashable {
    case camera
    case microphone
    case cameraAndMicrophone
    case location

    public var title: String {
        switch self {
        case .camera:
            return "Camera"
        case .microphone:
            return "Microphone"
        case .cameraAndMicrophone:
            return "Camera & Microphone"
        case .location:
            return "Location"
        }
    }

    public var promptVerb: String {
        switch self {
        case .location:
            return "use your"
        default:
            return "access your"
        }
    }
}

public struct WebPermissionPromptRequest: Codable, Hashable {
    public let id: UUID
    public let host: String
    public let kind: WebPermissionKind

    public init(id: UUID = UUID(), host: String, kind: WebPermissionKind) {
        self.id = id
        self.host = host
        self.kind = kind
    }
}

public enum WebPermissionPromptDecision: String, Codable, Hashable {
    case allow
    case deny
}

public struct WebPermissionPromptResponse: Codable, Hashable {
    public let id: UUID
    public let decision: WebPermissionPromptDecision

    public init(id: UUID, decision: WebPermissionPromptDecision) {
        self.id = id
        self.decision = decision
    }
}

public extension Notification.Name {
    /// object: WebPermissionPromptRequest
    static let webPermissionPromptRequested = Notification.Name("webPermissionPromptRequested")
    /// object: WebPermissionPromptResponse
    static let webPermissionPromptResponded = Notification.Name("webPermissionPromptResponded")
}
