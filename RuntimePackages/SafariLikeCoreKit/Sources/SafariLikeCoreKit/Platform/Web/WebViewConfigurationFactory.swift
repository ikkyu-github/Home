import WebKit

/// Builds `WKWebViewConfiguration` instances for the Safari-like runtime.
///
/// Threading:
/// - การสร้างอินสแตนซ์ (`init`) สามารถทำได้จาก context ใดก็ได้ (ไม่ถูกผูกกับ main actor).
/// - การสร้าง `WKWebViewConfiguration` จริง ๆ ต้องรันบน main actor เท่านั้น
///   ผ่านเมทอดที่มีการทำเครื่องหมาย `@MainActor`.
///
/// Keeping this in **CoreKit** avoids a hard dependency on the UI layer.
public final class WebViewConfigurationFactory {
    /// Threading: Nonisolated – สามารถเรียกจาก context ใดก็ได้.
    public init() {}

    /// สะดวกสำหรับ caller เดิมที่มี websiteDataStore อยู่แล้ว
    /// Threading: Call on the main actor.
    @MainActor
    public func makeConfiguration(websiteDataStore: WKWebsiteDataStore) -> WKWebViewConfiguration {
        // Best-effort inference for legacy call sites.
        let inferredProfile: BrowsingProfile = (websiteDataStore === WKWebsiteDataStore.nonPersistent())
            ? .private
            : .regular
        return makeConfiguration(profile: inferredProfile)
    }

    /// Safari-like API: เลือกทั้ง data store และ process pool จากโปรไฟล์เดียว
    ///
    /// - profile: `.regular` → `WKWebsiteDataStore.default()`
    ///            `.private` → `WKWebsiteDataStore.nonPersistent()`
    /// Threading: Call on the main actor.
    @MainActor
    public func makeConfiguration(profile: BrowsingProfile) -> WKWebViewConfiguration {
        EngineController.shared.makeWebViewConfiguration(profile: profile)
    }

    /// Core builder ที่รับทั้ง data store และโปรไฟล์อย่างชัดเจน
    /// Threading: Call on the main actor.
    ///
    /// EngineController is responsible for assigning the app-global `processPool`.
    @MainActor
    public func makeConfiguration(
        websiteDataStore: WKWebsiteDataStore,
        profile: BrowsingProfile
    ) -> WKWebViewConfiguration {
        // Policy is locked by profile; ignore the provided data store.
        _ = websiteDataStore
        return makeConfiguration(profile: profile)
    }
}
