import XCTest
@testable import BrowserCore
import SafariLikeContracts

final class TelemetryEngineTests: XCTestCase {

    func testSanitizerDropsForbiddenKeys() {
        let event = TelemetryEvent(
            type: .appLaunch,
            sceneID: "scene",
            attributes: [
                "url": "https://example.com",
                "title": "Example",
                "ok": "value"
            ]
        )

        let sanitized = TelemetrySanitizer.sanitize(event)
        XCTAssertNil(sanitized.attributes["url"])
        XCTAssertNil(sanitized.attributes["title"])
        XCTAssertEqual(sanitized.attributes["ok"], "value")
    }

    func testSanitizerDropsUrlLikeValues() {
        let event = TelemetryEvent(
            type: .navigationFailed,
            sceneID: "scene",
            attributes: [
                "error": "http://example.com",
                "note": "www.example.com",
                "ok": "E_CONNRESET"
            ]
        )

        let sanitized = TelemetrySanitizer.sanitize(event)
        XCTAssertNil(sanitized.attributes["error"])
        XCTAssertNil(sanitized.attributes["note"])
        XCTAssertEqual(sanitized.attributes["ok"], "E_CONNRESET")
    }

    func testEngineRingBufferIsBounded() {
        let engine = TelemetryEngine(configuration: .init(capacity: 32, persistence: nil))
        for i in 0..<100 {
            engine.record(TelemetryEvent(type: .appLaunch, attributes: ["i": "\(i)"]))
        }
        let snap = engine.snapshot()
        XCTAssertEqual(snap.count, 32)
        XCTAssertEqual(snap.last?.attributes["i"], "99")
    }
}
