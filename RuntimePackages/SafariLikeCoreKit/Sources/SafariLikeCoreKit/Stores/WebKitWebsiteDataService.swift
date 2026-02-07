import Foundation
import WebKit
import SafariLikeContracts
import BrowserCore

/// WebKit-backed website data service.
///
/// Swift 6 / actor isolation:
/// - All `WKWebsiteDataStore` and `WKWebsiteDataRecord` access is performed on the `MainActor`.
/// - Public API remains Sendable via this actor boundary.
public actor WebKitWebsiteDataService: WebsiteDataServicing {
    public init() {}

    public func fetchRecords(profile: WebsiteDataProfile) async throws -> [WebsiteDataRecord] {
        let dataStore = try await resolveDataStore(profile: profile)
        let webKitTypes = await MainActor.run { WKWebsiteDataStore.allWebsiteDataTypes() }

        let records = await fetchDataRecords(dataStore: dataStore, ofTypes: webKitTypes)
        return await MainActor.run {
            records
                .map { record in
                    let displayName = record.displayName
                    let siteKey = SiteKey(host: displayName)
                    let mappedTypes = Set(record.dataTypes.map { Self.mapFromWebKitType($0) })
                    return WebsiteDataRecord(
                        displayName: displayName,
                        siteKey: siteKey,
                        dataTypes: mappedTypes,
                        approximateSizeBytes: nil
                    )
                }
                .sorted { $0.siteKey.storageKey < $1.siteKey.storageKey }
        }
    }

    public func clear(request: ClearWebsiteDataRequest) async throws {
        let dataStore = try await resolveDataStore(profile: request.profile)

        let requestedWebKitTypes: Set<String>
        if request.dataTypes.isEmpty {
            requestedWebKitTypes = await MainActor.run { WKWebsiteDataStore.allWebsiteDataTypes() }
        } else {
            requestedWebKitTypes = Set(request.dataTypes.map { Self.mapToWebKitType($0) })
        }

        switch request.scope {
        case .all(let timeRange):
            let modifiedSince = timeRange.modifiedSince(now: Date())
            await removeData(dataStore: dataStore, ofTypes: requestedWebKitTypes, modifiedSince: modifiedSince)

        case .site(let siteKey):
            // WebKit API does not support time-scoped per-site deletion.
            // Best-effort: remove requested types for matching records.
            let records = await fetchDataRecords(dataStore: dataStore, ofTypes: requestedWebKitTypes)

            let matching: [WKWebsiteDataRecord] = await MainActor.run {
                records.filter { SiteKey(host: $0.displayName).storageKey == siteKey.storageKey }
            }
            guard matching.isEmpty == false else { return }

            await removeData(dataStore: dataStore, ofTypes: requestedWebKitTypes, for: matching)

        @unknown default:
            assertionFailure("Unhandled scope: \(request.scope)")
            return
        }
    }

    public func supportedDataTypes(profile: WebsiteDataProfile) async -> Set<WebsiteDataType> {
        _ = profile
        let webKitTypes = await MainActor.run { WKWebsiteDataStore.allWebsiteDataTypes() }
        return Set(webKitTypes.map { Self.mapFromWebKitType($0) })
    }

    // MARK: - Private

    private func resolveDataStore(profile: WebsiteDataProfile) async throws -> WKWebsiteDataStore {
        switch profile {
        case .regular:
            return await MainActor.run { WKWebsiteDataStore.default() }
        case .private:
            // Parity gap: EngineController currently creates distinct nonPersistent stores per WebView.
            // Without access to those instances, we cannot enumerate/clear private mode data safely.
            throw WebsiteDataServiceError.unsupportedProfile

        @unknown default:
            assertionFailure("Unhandled profile: \(profile)")
            throw WebsiteDataServiceError.unsupportedProfile
        }
    }

    @MainActor
    private func fetchDataRecords(
        dataStore: WKWebsiteDataStore,
        ofTypes types: Set<String>
    ) async -> [WKWebsiteDataRecord] {
        await withCheckedContinuation { (cont: CheckedContinuation<[WKWebsiteDataRecord], Never>) in
            dataStore.fetchDataRecords(ofTypes: types) { recs in
                cont.resume(returning: recs)
            }
        }
    }

    @MainActor
    private func removeData(
        dataStore: WKWebsiteDataStore,
        ofTypes types: Set<String>,
        modifiedSince date: Date
    ) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            dataStore.removeData(ofTypes: types, modifiedSince: date) {
                cont.resume(returning: ())
            }
        }
    }

    @MainActor
    private func removeData(
        dataStore: WKWebsiteDataStore,
        ofTypes types: Set<String>,
        for records: [WKWebsiteDataRecord]
    ) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            dataStore.removeData(ofTypes: types, for: records) {
                cont.resume(returning: ())
            }
        }
    }

    private static func mapFromWebKitType(_ type: String) -> WebsiteDataType {
        switch type {
        case WKWebsiteDataTypeCookies:
            return .cookies
        case WKWebsiteDataTypeDiskCache:
            return .diskCache
        case WKWebsiteDataTypeMemoryCache:
            return .memoryCache
        case WKWebsiteDataTypeLocalStorage:
            return .localStorage
        case WKWebsiteDataTypeSessionStorage:
            return .sessionStorage
        case WKWebsiteDataTypeIndexedDBDatabases:
            return .indexedDB
        case WKWebsiteDataTypeServiceWorkerRegistrations:
            return .serviceWorkers
        case WKWebsiteDataTypeOfflineWebApplicationCache:
            return .offlineWebAppCache
        default:
            return WebsiteDataType(rawValue: type)
        }
    }

    private static func mapToWebKitType(_ type: WebsiteDataType) -> String {
        switch type {
        case .cookies:
            return WKWebsiteDataTypeCookies
        case .diskCache:
            return WKWebsiteDataTypeDiskCache
        case .memoryCache:
            return WKWebsiteDataTypeMemoryCache
        case .localStorage:
            return WKWebsiteDataTypeLocalStorage
        case .sessionStorage:
            return WKWebsiteDataTypeSessionStorage
        case .indexedDB:
            return WKWebsiteDataTypeIndexedDBDatabases
        case .serviceWorkers:
            return WKWebsiteDataTypeServiceWorkerRegistrations
        case .offlineWebAppCache:
            return WKWebsiteDataTypeOfflineWebApplicationCache
        default:
            return type.rawValue
        }
    }
}
