# webOS / SafariLike* Workspace

This repository contains multiple components that are at different stages of evolution.
Some folders are **reference-only** and are **not** part of the code that is built or shipped.

## Reference-only folders (do not build from here)

- `Blueprint/`
  - Design notes and experimental structure.
  - Used as an architectural reference only.
  - **Not** compiled as part of the main app.

- `Docs/Blueprint/`
  - Contains blueprint reorg trees and historical layout archives.
  - Purely documentation/architecture reference.
  - **Not part of any Xcode target or build output.**

- `_Archive/`
  - Legacy code kept for historical/reference purposes.
  - May contain outdated APIs and architecture.
  - **Not** used by the current build.

## Active code

The active, buildable sources live primarily in:

- `App/`
- `BrowserCore/`
- `Core/`
- `Features/`
- `Models/`
- `SafariLikeCoreKit/`
- `SafariLikeKit/`
- `SafariLikeUIKit/`
- `webOS/`

When in doubt, treat anything under `Blueprint/` and `_Archive/` as read-only reference material and follow the patterns in the active folders above for new work.
