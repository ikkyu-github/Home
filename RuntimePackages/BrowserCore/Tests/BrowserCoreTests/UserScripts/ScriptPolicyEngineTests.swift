import XCTest
@testable import BrowserCore
import SafariLikeContracts

final class ScriptPolicyEngineTests: XCTestCase {
    func testGlobalDisabledBlocksAll() {
        let engine = ScriptPolicyEngine()
        let scripts = [makeScript(name: "A", includeHosts: ["example.com"]) ]
        let policy = ScriptPolicy(globalEnabled: false)

        let allowed = engine.allowedScripts(
            scripts: scripts,
            policy: policy,
            siteKey: SiteKey(host: "example.com"),
            url: URL(string: "https://example.com"),
            profile: .regular
        )

        XCTAssertEqual(allowed.count, 0)
    }

    func testPrivateBlockedByDefault() {
        let engine = ScriptPolicyEngine()
        let scripts = [makeScript(name: "A")]
        let policy = ScriptPolicy(globalEnabled: true, privateModeEnabled: false)

        let allowed = engine.allowedScripts(
            scripts: scripts,
            policy: policy,
            siteKey: SiteKey(host: "example.com"),
            url: URL(string: "https://example.com"),
            profile: .private
        )

        XCTAssertEqual(allowed.count, 0)
    }

    func testSiteOverrideDisabledBlocksAll() {
        let engine = ScriptPolicyEngine()
        let scripts = [makeScript(name: "A")]
        var policy = ScriptPolicy(globalEnabled: true, privateModeEnabled: true)
        policy.perSiteOverrides[SiteKey(host: "example.com").storageKey] = false

        let allowed = engine.allowedScripts(
            scripts: scripts,
            policy: policy,
            siteKey: SiteKey(host: "example.com"),
            url: URL(string: "https://example.com"),
            profile: .regular
        )

        XCTAssertEqual(allowed.count, 0)
    }

    func testIncludeExcludeHostMatching() {
        let engine = ScriptPolicyEngine()

        let s1 = makeScript(name: "AllowSubdomains", includeHosts: ["*.example.com"])
        let s2 = makeScript(name: "ExcludeAdmin", includeHosts: ["*.example.com"], excludeHosts: ["admin.example.com"])

        let policy = ScriptPolicy(globalEnabled: true, privateModeEnabled: true)

        let allowed1 = engine.allowedScripts(
            scripts: [s1, s2],
            policy: policy,
            siteKey: SiteKey(host: "news.example.com"),
            url: URL(string: "https://news.example.com/article"),
            profile: .regular
        )
        XCTAssertEqual(allowed1.map(\.name), ["AllowSubdomains", "ExcludeAdmin"])

        let allowed2 = engine.allowedScripts(
            scripts: [s1, s2],
            policy: policy,
            siteKey: SiteKey(host: "admin.example.com"),
            url: URL(string: "https://admin.example.com"),
            profile: .regular
        )
        XCTAssertEqual(allowed2.map(\.name), ["AllowSubdomains"])
    }

    func testURLPatternMatching() {
        let engine = ScriptPolicyEngine()

        let script = UserScript(
            name: "OnlyArticles",
            description: "",
            sourceCode: "console.log(1)",
            injectionTime: .documentEnd,
            isEnabled: true,
            profilesAllowed: [.regular],
            matchRules: UserScriptMatchRules(
                includeHosts: ["example.com"],
                excludeHosts: [],
                includeURLPatterns: ["*/article/*"],
                excludeURLPatterns: ["*/article/drafts/*"]
            )
        )

        let policy = ScriptPolicy(globalEnabled: true)

        let allowed1 = engine.allowedScripts(
            scripts: [script],
            policy: policy,
            siteKey: SiteKey(host: "example.com"),
            url: URL(string: "https://example.com/article/123"),
            profile: .regular
        )
        XCTAssertEqual(allowed1.count, 1)

        let allowed2 = engine.allowedScripts(
            scripts: [script],
            policy: policy,
            siteKey: SiteKey(host: "example.com"),
            url: URL(string: "https://example.com/article/drafts/1"),
            profile: .regular
        )
        XCTAssertEqual(allowed2.count, 0)
    }

    func testDeterministicOrdering() {
        let engine = ScriptPolicyEngine()

        var a = makeScript(name: "B", injectionTime: .documentEnd)
        a.id = UserScriptID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)

        var b = makeScript(name: "A", injectionTime: .documentEnd)
        b.id = UserScriptID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)

        let c = makeScript(name: "C", injectionTime: .documentStart)

        let allowed = engine.allowedScripts(
            scripts: [a, b, c],
            policy: ScriptPolicy(globalEnabled: true, privateModeEnabled: true),
            siteKey: SiteKey(host: "example.com"),
            url: URL(string: "https://example.com"),
            profile: .regular
        )

        XCTAssertEqual(allowed.map(\.injectionTime), [.documentStart, .documentEnd, .documentEnd])
        XCTAssertEqual(allowed.map(\.name), ["C", "A", "B"])
    }

    // MARK: - Helpers

    private func makeScript(
        name: String,
        injectionTime: InjectionTime = .documentEnd,
        includeHosts: [String] = [],
        excludeHosts: [String] = []
    ) -> UserScript {
        UserScript(
            name: name,
            description: "",
            sourceCode: "console.log(1)",
            injectionTime: injectionTime,
            isEnabled: true,
            profilesAllowed: [.regular, .private],
            matchRules: UserScriptMatchRules(
                includeHosts: includeHosts,
                excludeHosts: excludeHosts
            )
        )
    }
}
