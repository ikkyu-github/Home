# Asset Catalog Audit (AssetsDev.xcassets / AssetsRuntime.xcassets)

Date: 2026-01-22

## 1) Duplicate names / duplicate content

- `AssetsDev.xcassets` contained no asset sets (only `Contents.json`).
- `AssetsRuntime.xcassets` contained:
  - `AccentColor.colorset`
  - `AppIcon.appiconset`

Result:
- No duplicate asset names between the two catalogs.
- No duplicate content to merge.

## 2) Unreferenced assets (code / storyboard)

These assets are typically referenced by Xcode build settings (not by explicit string literals in code/storyboards):

- `AppIcon` is referenced by `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;`.
- `AccentColor` is referenced by `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;` and used implicitly by SwiftUI/asset pipeline.

Result:
- No safe removals identified.

## 3) Shared asset consolidation

- Not applicable here because there were no duplicates.

## 4) New Assets.xcassets structure

A new consolidated catalog was created with the requested structure:

- `Assets.xcassets/Shared/` (contains `AccentColor.colorset`)
- `Assets.xcassets/RuntimeOnly/` (contains `AppIcon.appiconset`)
- `Assets.xcassets/DevOnly/` (empty for now)

Important: the folder grouping does **not** namespace asset names, so runtime names remain `AccentColor` and `AppIcon`.

## 5) Reference updates

- No code/storyboard string references required changes because asset *names* were not changed.
- The Xcode project was updated to reference `Assets.xcassets` instead of the two older catalogs.

