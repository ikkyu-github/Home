import Foundation

public enum NetworkPathStatus: String, Codable, Sendable {
    case satisfied
    case unsatisfied
    case requiresConnection
    case unknown
}

public enum NetworkInterfaceType: String, Codable, Sendable {
    case wifi
    case cellular
    case wiredEthernet
    case loopback
    case other
}

public struct NetworkStatusSnapshot: Codable, Hashable, Sendable {
    public var status: NetworkPathStatus
    public var primaryInterface: NetworkInterfaceType?
    public var isExpensive: Bool
    public var isConstrained: Bool
    public var supportsIPv4: Bool
    public var supportsIPv6: Bool
    public var timestamp: Date

    public init(
        status: NetworkPathStatus,
        primaryInterface: NetworkInterfaceType?,
        isExpensive: Bool,
        isConstrained: Bool,
        supportsIPv4: Bool,
        supportsIPv6: Bool,
        timestamp: Date = Date()
    ) {
        self.status = status
        self.primaryInterface = primaryInterface
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
        self.supportsIPv4 = supportsIPv4
        self.supportsIPv6 = supportsIPv6
        self.timestamp = timestamp
    }
}
