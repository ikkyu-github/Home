# Refactor Report: Dedup + Extensions Consolidation (22 ม.ค. 2569)

Scope:
- SafariLikeCoreKit
- SafariLikeUIKit
- SafariLikeKit

## Summary

- เป้าหมาย: ลดไฟล์/ลด duplication/แยก SSOT ให้ชัด โดย **ไม่เปลี่ยน behavior** และ **ไม่ merge logic ที่ต่างกัน**
- ผลลัพธ์หลัก:
  - รวม extension ที่กระจายหลายไฟล์ → ไปไว้ที่ `SafariLikeKit/Extensions/Shared/`
  - รวมไฟล์ re-export/typealias ของ CoreKit ใน SafariLikeKit → เหลือไฟล์เดียว
  - ลบไฟล์ migration stub/comment-only และ extension ที่ไม่ถูกใช้งาน (ภายใน module)

## Duplicate Scan (evidence)

- Exact duplicate files (byte-identical) ข้าม 3 framework: ไม่พบ
- Duplicate extension blocks แบบเหมือนกันทุกประการ: ไม่พบ
- “Duplication” ที่พบส่วนใหญ่เป็นการทำ re-export ผ่าน `typealias` (ตั้งใจให้เป็น façade) มากกว่าการคัดลอก logic

## Changes

### SafariLikeKit

- Consolidated extensions:
  - New: `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Extensions/Shared/WKWebView+Shared.swift`
  - New: `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Extensions/Shared/UIApplication+TopMost.swift`
  - New: `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Extensions/Shared/View+SafariUI.swift`
  - Deleted: `Platform/Web/WKWebView+JavaScriptAsync.swift`
  - Deleted: `Platform/Web/WKWebViewAccessoryControl.swift`
  - Deleted: `Extensions/UIApplication+TopMost.swift`
  - Deleted: `UI/Interactions/SafariPressable.swift`
  - Deleted: `UI/Utilities/AnimationCompletion.swift`
  - Deleted: `UI/Scroll/ScrollViewTuning.swift`

- Removed unused internal extension:
  - Deleted: `Platform/Web/URLExtensions+YouTube.swift`

- Reduced facade file count:
  - New: `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Reexports/CoreKitReexports.swift`
  - Deleted:
    - `Runtime/Policy/PolicyCenter.swift`
    - `Runtime/Policy/PolicyTypes.swift`
    - `Plugins/Core/PluginCapability.swift`
    - `Core/Protocols/ContentBlockingProviding.swift`
    - `Core/ChromePolicy.swift`
    - `Core/Models/TabGroupColorFacade.swift`
    - `Core/Models/CompanionModels.swift`
    - `Core/Related/RelatedLinkExtractor.swift`
    - `Platform/Web/WebViewConfigurationFactory.swift`

- Tightened layering:
  - `Config/SafariLikeConfiguration.swift` removed `import UIKit` (ไม่จำเป็น)

### SafariLikeUIKit

- Warning fix (Swift 6): `Composition/UIKitMemoryPressureSource.swift` now captures handler locally to avoid MainActor property access from a Sendable closure.

### SafariLikeKit UI adapter

- Warning fix (Swift 6): `UI/ChromePolicyTraitCollectionAdapter.swift` now imports `SafariLikeCoreKit` because it extends a CoreKit-backed typealias.

## Verification

- `xcodebuild -configuration Debug build` succeeds.
- No new warnings from the refactor changes; remaining warnings are from AppIntents metadata extraction being skipped (tooling-level).

## Net file count change (this pass)

- Deleted: 18 files
- Added: 4 files
- Net: -14 files

