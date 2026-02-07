import Foundation

public enum ParityCheckStatus: String, Codable, Sendable, Hashable {
    case pass
    case warn
    case fail
}

public struct ParityCheckResult: Codable, Sendable, Hashable {
    public var checkID: String
    public var status: ParityCheckStatus
    public var message: String

    public init(checkID: String, status: ParityCheckStatus, message: String) {
        self.checkID = checkID
        self.status = status
        self.message = message
    }
}

public struct ParityReportSummary: Codable, Sendable, Hashable {
    public var passCount: Int
    public var warnCount: Int
    public var failCount: Int

    public init(passCount: Int, warnCount: Int, failCount: Int) {
        self.passCount = passCount
        self.warnCount = warnCount
        self.failCount = failCount
    }
}

public struct ParityReport: Codable, Sendable, Hashable {
    public var generatedAt: Date
    public var results: [ParityCheckResult]
    public var summary: ParityReportSummary

    public init(generatedAt: Date = Date(), results: [ParityCheckResult]) {
        self.generatedAt = generatedAt
        self.results = results
        let passCount = results.filter { $0.status == .pass }.count
        let warnCount = results.filter { $0.status == .warn }.count
        let failCount = results.filter { $0.status == .fail }.count
        self.summary = ParityReportSummary(passCount: passCount, warnCount: warnCount, failCount: failCount)
    }
}
