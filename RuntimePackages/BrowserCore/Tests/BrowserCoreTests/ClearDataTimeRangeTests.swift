import XCTest
@testable import BrowserCore
import SafariLikeContracts

final class ClearDataTimeRangeTests: XCTestCase {
    func testModifiedSince_todayAndYesterdayUsesStartOfYesterday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // 2026-01-03T15:00:00Z
        let now = Date(timeIntervalSince1970: 1767452400)

        let modifiedSince = ClearDataTimeRange.todayAndYesterday.modifiedSince(now: now, calendar: calendar)

        let startOfToday = calendar.startOfDay(for: now)
        let expected = calendar.date(byAdding: .day, value: -1, to: startOfToday)
        XCTAssertEqual(modifiedSince, expected)
    }
}
