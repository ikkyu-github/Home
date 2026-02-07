import XCTest
@testable import BrowserCore

final class HeuristicsEngineTests: XCTestCase {
    
    var engine: HeuristicsEngine!
    var thresholds: HeuristicsEngine.Thresholds!
    
    override func setUp() {
        super.setUp()
        thresholds = .init(
            fastLoadTimeMs: 1000,
            slowLoadTimeMs: 5000,
            crashThreshold: 3,
            heavyMemoryThreshold: 70,
            restoreFailureThreshold: 2
        )
        engine = HeuristicsEngine(thresholds: thresholds)
    }
    
    // MARK: - Policy Computation Tests
    
    func testPolicyForFastStableSite() {
        var model = SiteHeuristicsModel(siteKey: "example.com")
        model.avgLoadTimeMs = 800
        model.crashCount = 0
        model.memoryHotnessScore = 30
        model.restoreFailureCount = 0
        
        let policy = engine.computePolicy(from: model)
        
        XCTAssertTrue(policy.allowPrewarmWebView)
        XCTAssertEqual(policy.discardAggressiveness, 1) // Gentle
        XCTAssertEqual(policy.navigationThrottle, .low)
        XCTAssertEqual(policy.thumbnailCapturePolicy, .always)
    }
    
    func testPolicyForCrashingSite() {
        var model = SiteHeuristicsModel(siteKey: "crash.example.com")
        model.avgLoadTimeMs = 2000
        model.crashCount = 5 // exceeds threshold
        model.memoryHotnessScore = 80
        model.restoreFailureCount = 0
        
        let policy = engine.computePolicy(from: model)
        
        XCTAssertFalse(policy.allowPrewarmWebView)
        XCTAssertEqual(policy.discardAggressiveness, 3) // Aggressive
        XCTAssertEqual(policy.navigationThrottle, .high)
        XCTAssertEqual(policy.thumbnailCapturePolicy, .never)
    }
    
    func testPolicyForSensitiveSite() {
        var model = SiteHeuristicsModel(siteKey: "bank.example.com")
        model.avgLoadTimeMs = 1500
        model.crashCount = 0
        model.privacyFlags = .init(
            isTracking: false,
            requiresPersistentStorage: true,
            isSensitive: true
        )
        
        let policy = engine.computePolicy(from: model)
        
        XCTAssertFalse(policy.allowPrewarmWebView)
        XCTAssertEqual(policy.discardAggressiveness, 0) // Never discard
        XCTAssertEqual(policy.navigationThrottle, .normal)
    }
    
    func testPolicyForSlowLoadingSite() {
        var model = SiteHeuristicsModel(siteKey: "slow.example.com")
        model.avgLoadTimeMs = 6000 // exceeds threshold
        model.crashCount = 0
        model.memoryHotnessScore = 40
        
        let policy = engine.computePolicy(from: model)
        
        XCTAssertFalse(policy.allowPrewarmWebView)
        XCTAssertEqual(policy.discardAggressiveness, 3) // Aggressive due to slow
        XCTAssertEqual(policy.navigationThrottle, .normal)
    }
    
    func testPolicyForHeavyMemorySite() {
        var model = SiteHeuristicsModel(siteKey: "heavy.example.com")
        model.avgLoadTimeMs = 1000
        model.crashCount = 0
        model.memoryHotnessScore = 85 // exceeds threshold
        
        let policy = engine.computePolicy(from: model)
        
        XCTAssertFalse(policy.allowPrewarmWebView)
        XCTAssertEqual(policy.discardAggressiveness, 3)
        XCTAssertEqual(policy.thumbnailCapturePolicy, .never) // Save memory
    }
    
    // MARK: - Update Logic Tests
    
    func testUpdateWithLoadTime() {
        let model = SiteHeuristicsModel(siteKey: "test.com", avgLoadTimeMs: 0)
        let t0 = Date(timeIntervalSince1970: 0)
        
        // First observation
        let metrics1 = HeuristicsEngine.Metrics(observedAt: t0, loadTimeMs: 1000)
        let updated1 = engine.update(model: model, with: metrics1)
        XCTAssertEqual(updated1.avgLoadTimeMs, 1000)
        
        // Second observation: EMA
        let metrics2 = HeuristicsEngine.Metrics(observedAt: t0.addingTimeInterval(1), loadTimeMs: 1500)
        let updated2 = engine.update(model: updated1, with: metrics2)
        // 0.8 * 1000 + 0.2 * 1500 = 1100
        XCTAssertEqual(updated2.avgLoadTimeMs, 1100, accuracy: 0.1)
    }
    
    func testUpdateWithCrash() {
        let model = SiteHeuristicsModel(siteKey: "test.com", crashCount: 0, memoryHotnessScore: 30)
        
        let metrics = HeuristicsEngine.Metrics(observedAt: Date(timeIntervalSince1970: 0), didCrash: true)
        let updated = engine.update(model: model, with: metrics)
        
        XCTAssertEqual(updated.crashCount, 1)
        XCTAssertEqual(updated.memoryHotnessScore, 45) // +15 for crash
    }
    
    func testUpdateCrashCountCapped() {
        let model = SiteHeuristicsModel(siteKey: "test.com", crashCount: 99)
        
        let metrics = HeuristicsEngine.Metrics(observedAt: Date(timeIntervalSince1970: 0), didCrash: true)
        let updated = engine.update(model: model, with: metrics)
        
        XCTAssertEqual(updated.crashCount, 100) // Capped at 100
    }
    
    func testUpdateWithMediaHeavy() {
        let model = SiteHeuristicsModel(siteKey: "test.com", isMediaHeavy: false)
        
        let metrics = HeuristicsEngine.Metrics(observedAt: Date(timeIntervalSince1970: 0), isMediaHeavy: true)
        let updated = engine.update(model: model, with: metrics)
        
        XCTAssertTrue(updated.isMediaHeavy)
    }
    
    // MARK: - Health Score Tests
    
    func testHealthScorePerfect() {
        var model = SiteHeuristicsModel(siteKey: "perfect.com")
        model.avgLoadTimeMs = 800
        model.crashCount = 0
        model.memoryHotnessScore = 30
        model.restoreFailureCount = 0
        
        let score = engine.healthScore(from: model)
        
        // 100 - 0 - 0 - 15 - 0 = 85
        XCTAssertGreaterThanOrEqual(score, 80)
    }
    
    func testHealthScoreBad() {
        var model = SiteHeuristicsModel(siteKey: "bad.com")
        model.avgLoadTimeMs = 8000
        model.crashCount = 5
        model.memoryHotnessScore = 100
        model.restoreFailureCount = 3
        
        let score = engine.healthScore(from: model)
        
        // 100 - 50 - 20 - 50 - 15 = clamped to 0
        XCTAssertLessThanOrEqual(score, 20)
    }
    
    // MARK: - Risk Detection Tests
    
    func testIsRiskySite() {
        var model = SiteHeuristicsModel(siteKey: "risky.com")
        model.crashCount = 5
        
        XCTAssertTrue(engine.isRisky(model: model))
    }
    
    func testIsNotRiskySite() {
        let model = SiteHeuristicsModel(siteKey: "safe.com")
        
        XCTAssertFalse(engine.isRisky(model: model))
    }
}

final class SiteHeuristicsModelTests: XCTestCase {
    
    func testHostNormalization() {
        let url1 = URL(string: "https://www.example.com/path")!
        let url2 = URL(string: "https://example.com/path")!
        let url3 = URL(string: "https://sub.example.com/path")!
        
        let key1 = SiteHeuristicsModel.normalizeSiteKey(from: url1)
        let key2 = SiteHeuristicsModel.normalizeSiteKey(from: url2)
        let key3 = SiteHeuristicsModel.normalizeSiteKey(from: url3)
        
        // www should be stripped
        XCTAssertEqual(key1, "example.com")
        XCTAssertEqual(key2, "example.com")
        // Subdomains get eTLD+1
        XCTAssertEqual(key3, "example.com")
    }
    
    func testIPAddressNormalization() {
        let url = URL(string: "http://127.0.0.1:8000/")!
        let key = SiteHeuristicsModel.normalizeSiteKey(from: url)
        
        XCTAssertEqual(key, "127.0.0.1")
    }
    
    func testLocalhostNormalization() {
        let url = URL(string: "http://localhost:3000/")!
        let key = SiteHeuristicsModel.normalizeSiteKey(from: url)
        
        XCTAssertEqual(key, "localhost")
    }
    
    func testCodable() {
        var model = SiteHeuristicsModel(siteKey: "example.com")
        model.avgLoadTimeMs = 1234.5
        model.crashCount = 2
        model.memoryHotnessScore = 65
        
        let encoded = try! JSONEncoder().encode(model)
        let decoded = try! JSONDecoder().decode(SiteHeuristicsModel.self, from: encoded)
        
        XCTAssertEqual(decoded, model)
    }
}

final class SitePolicyTests: XCTestCase {
    
    func testDefaultPolicy() {
        let policy = SitePolicy.default
        
        XCTAssertFalse(policy.allowPrewarmWebView)
        XCTAssertEqual(policy.discardAggressiveness, 2)
        XCTAssertEqual(policy.navigationThrottle, .normal)
    }
    
    func testSensitivePolicy() {
        let policy = SitePolicy.sensitive
        
        XCTAssertFalse(policy.allowPrewarmWebView)
        XCTAssertEqual(policy.discardAggressiveness, 0)
    }
    
    func testTrustedPolicy() {
        let policy = SitePolicy.trusted
        
        XCTAssertTrue(policy.allowPrewarmWebView)
        XCTAssertEqual(policy.discardAggressiveness, 1)
        XCTAssertEqual(policy.navigationThrottle, .low)
    }
    
    func testAggressivenessClamping() {
        let policy1 = SitePolicy(discardAggressiveness: -1)
        let policy2 = SitePolicy(discardAggressiveness: 5)
        
        XCTAssertEqual(policy1.discardAggressiveness, 0)
        XCTAssertEqual(policy2.discardAggressiveness, 3)
    }
}
