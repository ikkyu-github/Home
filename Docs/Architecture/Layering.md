# Layering Notes

This repo enforces strict layering:

- **UI**: `App/`, `RuntimePackages/SafariLikeUIKit/`, `RuntimePackages/SafariLikeKit/`
- **Domain**: `RuntimePackages/BrowserCore/`
- **Runtime/Core**: `RuntimePackages/SafariLikeCoreKit/`
- **Contracts**: `RuntimePackages/SafariLikeContracts/`

## Removed placeholder files (intentional)

The following placeholder files were deleted because they existed only to demonstrate *what must not live in CoreKit* and caused confusion in production snapshots:

- `RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Snapshot/SnapshotService.swift`
- `RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Stores/TabThumbnailStore.swift`

### Where the real functionality lives

- **Snapshots**: use the runtime implementation in `SafariLikeKit` (UI/runtime layer), then expose data across layers via protocols in `SafariLikeCoreKit`.
- **Thumbnails**: concrete thumbnail stores are UI-owned; CoreKit only depends on protocol boundaries.

If you need to reintroduce an API surface in CoreKit, add a protocol in CoreKit/Contracts and keep concrete `UIImage`/filesystem/webview coupling in the UI layers.
