import Foundation
import SafariLikeContracts

public extension ClearDataTimeRange {
    /// Best-effort `modifiedSince` date for time-scoped removals.
    ///
    /// - Note: This is used by adapters that only support time-based deletion.
    func modifiedSince(now: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .lastHour:
            return now.addingTimeInterval(-3600)

        case .today:
            return calendar.startOfDay(for: now)

        case .todayAndYesterday:
            let startOfToday = calendar.startOfDay(for: now)
            return calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday.addingTimeInterval(-86400)

        case .allTime:
            return .distantPast

        @unknown default:
            assertionFailure("Unhandled ClearDataTimeRange: \(self)")
            // Conservative default: clear as much as possible.
            return .distantPast
        }
    }
}
