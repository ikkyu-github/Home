import SafariLikeContracts
import SafariLikeCoreKit

/// Public accessors for core default store implementations.
///
/// App targets should use these to obtain concrete implementations without
/// importing lower-level modules directly.
@MainActor
public enum SafariLikeStores {
    public static func makeWebsitePreferencesStore() -> any WebsitePreferencesProviding {
        CoreStoreFactory.makeWebsitePreferencesStore()
    }
}
