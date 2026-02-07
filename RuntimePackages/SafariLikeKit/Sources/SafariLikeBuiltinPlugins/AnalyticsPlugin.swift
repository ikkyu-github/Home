import Foundation
import BrowserCore
import os
import SafariLikeContracts
/// Example Analytics Plugin - Demonstrates navigationRead capability
///
/// **What it does:**
/// - Observes navigation events via the host's simple navigation hooks
/// - Tracks page load metrics
/// - Records navigation history
@MainActor
public final class AnalyticsPlugin: BrowserPlugin {
    public init() {}
    public let id: String = "com.safarilike.analytics"
    public let capabilities: Set<PluginCapability> = [.navigationRead]
    private static let logger = Logger(subsystem: "SafariLikeBuiltinPlugins", category: "AnalyticsPlugin")
    private let sessionID = UUID().uuidString
    private var pageViews: [PageView] = []
    private var currentPageStartTime: Date?
    public struct PageView: Sendable {
        let url: String
        let timestamp: Date
        let duration: TimeInterval
        let referrer: String?
        let title: String?
    }
    public struct AnalyticsEvent: Sendable, Codable {
        let eventType: String
        let url: String
        let timestamp: Date
        let sessionID: String
        let properties: [String: String]
    }
    public func onLoad(context: any BrowserPluginContext) async throws {
        guard context.hasCapability(.navigationRead) else {
            throw PluginError.capabilityRequired(.navigationRead)
        }
        Self.logger.debug("Analytics Plugin loaded; session ID: \(self.sessionID, privacy: .public)")
    }
    public func onUnload() async throws {
        Self.logger.debug("Analytics Plugin unloaded; total page views: \(self.pageViews.count, privacy: .public)")
        await flushAnalytics()
    }
    public func onNavigationDidStart(_ request: NavigationRequest) {
        currentPageStartTime = Date()
        Self.logger.debug("Navigation started: \(request.url, privacy: .public)")
    }
    public func onNavigationDidFinish(_ request: NavigationRequest) {
        let duration = currentPageStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let pageView = PageView(
            url: request.url,
            timestamp: Date(),
            duration: duration,
            referrer: nil,
            title: nil
        )
        pageViews.append(pageView)
        let durationString = String(format: "%.2f", duration)
        Self.logger.debug("Page load completed: \(request.url, privacy: .public) (\(durationString, privacy: .public)s)")
        reportPageView(pageView)
    }
    public func onNavigationDidFail(_ request: NavigationRequest, error: Error) {
        Self.logger.debug("Navigation failed: \(request.url, privacy: .public) - \(error.localizedDescription, privacy: .public)")
        let event = AnalyticsEvent(
            eventType: "navigationError",
            url: request.url,
            timestamp: Date(),
            sessionID: sessionID,
            properties: [
                "error": error.localizedDescription,
                "errorType": "\(type(of: error))",
            ]
        )
        reportEvent(event)
    }
    public func onTabDidChange(from fromTabID: String, to toTabID: String) {
        Self.logger.debug("Tab switched: \(fromTabID, privacy: .public) → \(toTabID, privacy: .public)")
        let event = AnalyticsEvent(
            eventType: "tabSwitch",
            url: "",
            timestamp: Date(),
            sessionID: sessionID,
            properties: [
                "fromTab": fromTabID,
                "toTab": toTabID,
            ]
        )
        reportEvent(event)
    }
    // MARK: - BrowserPlugin (simple navigation hooks)
    public func navigationWillStart(url: URL) throws {
        let request = NavigationRequest(
            url: url.absoluteString,
            method: "GET",
            headers: [:],
            isMainFrame: true
        )
        onNavigationDidStart(request)
    }
    public func navigationDidFinish(url: URL) throws {
        let request = NavigationRequest(
            url: url.absoluteString,
            method: "GET",
            headers: [:],
            isMainFrame: true
        )
        onNavigationDidFinish(request)
    }
    public func navigationDidFail(url: URL, error: Error) throws {
        let request = NavigationRequest(
            url: url.absoluteString,
            method: "GET",
            headers: [:],
            isMainFrame: true
        )
        onNavigationDidFail(request, error: error)
    }
    // MARK: - Reporting
    private func reportPageView(_ pageView: PageView) {
        let event = AnalyticsEvent(
            eventType: "pageView",
            url: pageView.url,
            timestamp: pageView.timestamp,
            sessionID: sessionID,
            properties: [
                "duration": String(format: "%.2f", pageView.duration),
                "title": pageView.title ?? "Unknown",
            ]
        )
        reportEvent(event)
    }
    private func reportEvent(_ event: AnalyticsEvent) {
        Self.logger.debug("Reporting event: \(event.eventType, privacy: .public) for \(event.url, privacy: .public)")
    }
    private func flushAnalytics() async {
        try? await Task.sleep(nanoseconds: 100_000_000)
        Self.logger.debug("Analytics flushed")
    }
}
