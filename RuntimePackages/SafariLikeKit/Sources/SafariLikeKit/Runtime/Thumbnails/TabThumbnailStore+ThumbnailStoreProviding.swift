import SafariLikeContracts
import SafariLikeCoreKit
extension TabThumbnailStore: ThumbnailStoreProviding {
    public func makeThumbnailProvider() -> any TabThumbnailProviding {
        self
    }
}
