import Foundation
import SafariLikeCoreKit
#if canImport(ActivityKit) && os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
#endif
@MainActor
public final class BrowserLiveActivityManager {
    /// SAFE SINGLETON:
    /// - Process-wide bridge to ActivityKit (system service).
    /// - Must not store per-window/scene/tab identity (Live Activity is user-global).
    public static let shared = BrowserLiveActivityManager()
    private init() {}
#if canImport(ActivityKit) && os(iOS) && !targetEnvironment(macCatalyst)
    /// Stored as `Any` so this type can compile with iOS 15 deployment targets.
    /// Access is gated behind iOS 16.2 availability via the computed `activity`.
    private var activityBox: Any?
    @available(iOS 16.2, *)
    private var activity: Activity<BrowserLiveActivityAttributes>? {
        get { activityBox as? Activity<BrowserLiveActivityAttributes> }
        set { activityBox = newValue }
    }
    /// Keep a stable attributes id per activity lifecycle. Generating a new UUID per
    /// progress tick can cause repeated request attempts if the activity is nil.
    private var currentAttributesID: String = UUID().uuidString
    /// Coalesce frequent updates (progress can fire many times per second).
    private struct PendingUpdate {
        var title: String
        var url: URL?
        var progress: Double
        var isLoading: Bool
    }
    private var pending: PendingUpdate?
    private var coalesceTask: Task<Void, Never>?
    private var lastSentAt: CFTimeInterval = 0
    private let minUpdateInterval: CFTimeInterval = 0.25
    /// Minimum visible time so Live Activity doesn't "blink" on fast loads.
    private var activityStartedAt: Date?
#endif
    // MARK: - Public API
    public func update(
        title: String,
        url: URL?,
        progress: Double,
        isLoading: Bool
    ) {
#if canImport(ActivityKit) && os(iOS) && !targetEnvironment(macCatalyst)
        // Live Activity stable API uses ActivityContent in iOS 16.2+
        guard #available(iOS 16.2, *) else { return }
        // Best-effort: if the user has disabled Live Activities, don't waste cycles.
        if ActivityAuthorizationInfo().areActivitiesEnabled == false {
            return
        }
        // Coalesce very frequent updates (estimatedProgress can spam).
        pending = PendingUpdate(title: title, url: url, progress: progress, isLoading: isLoading)
        scheduleFlushPending()
#else
        _ = title; _ = url; _ = progress; _ = isLoading
#endif
    }
    public func end() {
#if canImport(ActivityKit) && os(iOS) && !targetEnvironment(macCatalyst)
        guard #available(iOS 16.2, *) else { return }
        guard let activity else { return }
        coalesceTask?.cancel()
        coalesceTask = nil
        pending = nil
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        self.activity = nil
        self.activityStartedAt = nil
        self.currentAttributesID = UUID().uuidString
#endif
    }
#if canImport(ActivityKit) && os(iOS) && !targetEnvironment(macCatalyst)
    // MARK: - Internals (iOS 16.2+ only)
    @available(iOS 16.2, *)
    private func scheduleFlushPending() {
        let now = CFAbsoluteTimeGetCurrent()
        // If enough time has passed, flush immediately.
        if (now - lastSentAt) >= minUpdateInterval {
            flushPendingNow()
            return
        }
        // Otherwise, schedule a single coalesced flush.
        if coalesceTask != nil { return }
        let remaining = max(0, minUpdateInterval - (now - lastSentAt))
        coalesceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            self.flushPendingNow()
        }
    }
    @available(iOS 16.2, *)
    private func flushPendingNow() {
        coalesceTask?.cancel()
        coalesceTask = nil
        guard let pending else { return }
        self.pending = nil
        let host = pending.url?.host ?? ""
        let displayTitle = pending.title.isEmpty ? (host.isEmpty ? "Browsing" : host) : pending.title
        let clamped = max(0, min(1, pending.progress))
        let state = BrowserLiveActivityAttributes.ContentState(
            title: displayTitle,
            host: host,
            progress: clamped,
            isLoading: pending.isLoading
        )
        let content = ActivityContent(state: state, staleDate: nil)
        lastSentAt = CFAbsoluteTimeGetCurrent()
        if pending.isLoading {
            startOrUpdate(attributesID: currentAttributesID, content: content)
        } else {
            finish(content: content)
        }
    }
    @available(iOS 16.2, *)
    private func startOrUpdate(
        attributesID: String,
        content: ActivityContent<BrowserLiveActivityAttributes.ContentState>
    ) {
        if activity == nil {
            let attributes = BrowserLiveActivityAttributes(id: attributesID)
            do {
                activity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                activityStartedAt = Date()
            } catch {
                activity = nil
                activityStartedAt = nil
            }
        } else {
            Task {
                await activity?.update(content)
            }
        }
    }
    @available(iOS 16.2, *)
    private func finish(
        content: ActivityContent<BrowserLiveActivityAttributes.ContentState>
    ) {
        guard let activity else { return }
        Task { @MainActor in
            await activity.update(content)
            // Avoid "blink": keep the activity visible for at least ~1s.
            let elapsed = Date().timeIntervalSince(activityStartedAt ?? Date.distantPast)
            let remaining = max(0, 1.0 - elapsed)
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            } else {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            await activity.end(
                content,
                dismissalPolicy: .after(Date().addingTimeInterval(1))
            )
            self.activity = nil
            self.activityStartedAt = nil
            self.currentAttributesID = UUID().uuidString
        }
    }
#endif
}
#if canImport(ActivityKit) && os(iOS) && !targetEnvironment(macCatalyst)
@available(iOS 16.2, *)
struct BrowserLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var host: String
        var progress: Double
        var isLoading: Bool
    }
    let id: String
}
#endif
