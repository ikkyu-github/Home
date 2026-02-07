import Foundation

public enum TabDiscardTrigger: Sendable, Equatable {
    public enum MemoryWarningLevel: Sendable, Equatable {
        case warning
        case critical
    }

    public enum ThermalState: Sendable, Equatable {
        case serious
        case critical
    }

    case memoryWarning(MemoryWarningLevel)
    case webViewOversubscribed
    case appBackgroundedLong(duration: TimeInterval)
    case tabInactiveSweep
    case tabCountHigh(count: Int)
    case thermalState(ThermalState)
}
