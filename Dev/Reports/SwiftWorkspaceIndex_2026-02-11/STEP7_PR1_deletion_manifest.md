# PR1 Deletion Manifest (Batch 1 — Production Sources only)

Rules enforced here:
- Only `classification=UNUSED` AND `visibility in {private,fileprivate,internal}` AND `risk_notes empty`.
- Only file deletions under `RuntimePackages/**/Sources/**` where Step2 shows exactly one type in file and no functions/extensions.
- No App target file deletions in PR1.

## Exact file deletions

- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/SplitFeatureFlags.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/SplitFeatureFlags.swift)
  - Symbol: SplitFeatureFlags
  - Evidence (STRICT_UNUSED classification/visibility): [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/SplitFeatureFlags.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/SplitFeatureFlags.swift#L3)
  - Evidence (Step2 file summary entry): [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/AppLifecyclePhase.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/AppLifecyclePhase.swift)
  - Symbol: AppLifecyclePhase
  - Evidence (STRICT_UNUSED classification/visibility): [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/AppLifecyclePhase.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/AppLifecyclePhase.swift#L3)
  - Evidence (Step2 file summary entry): [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/Controllers/TabSelectionTransaction.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/Controllers/TabSelectionTransaction.swift)
  - Symbol: TabSelectionTransaction
  - Evidence (STRICT_UNUSED classification/visibility): [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/Controllers/TabSelectionTransaction.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/Controllers/TabSelectionTransaction.swift#L6)
  - Evidence (Step2 file summary entry): [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/SplitBrowser/State/SplitBrowserState.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/SplitBrowser/State/SplitBrowserState.swift)
  - Symbol: SplitBrowserState
  - Evidence (STRICT_UNUSED classification/visibility): [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/SplitBrowser/State/SplitBrowserState.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/SplitBrowser/State/SplitBrowserState.swift#L6)
  - Evidence (Step2 file summary entry): [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/State/LayoutState.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/State/LayoutState.swift)
  - Symbol: LayoutState
  - Evidence (STRICT_UNUSED classification/visibility): [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/State/LayoutState.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/State/LayoutState.swift#L5)
  - Evidence (Step2 file summary entry): [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/State/NavigationState.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/State/NavigationState.swift)
  - Symbol: NavigationState
  - Evidence (STRICT_UNUSED classification/visibility): [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/State/NavigationState.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/State/NavigationState.swift#L4)
  - Evidence (Step2 file summary entry): [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Chrome/BrowserChromeView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Chrome/BrowserChromeView.swift)
  - Symbol: BrowserChromeView
  - Evidence (STRICT_UNUSED classification/visibility): [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Chrome/BrowserChromeView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Chrome/BrowserChromeView.swift#L5)
  - Evidence (Step2 file summary entry): [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/PrimaryPane.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/PrimaryPane.swift)
  - Symbol: PrimaryPane
  - Evidence (STRICT_UNUSED classification/visibility): [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/PrimaryPane.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/PrimaryPane.swift#L5)
  - Evidence (Step2 file summary entry): [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/BookmarksSheetView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/BookmarksSheetView.swift)
  - Symbol: BookmarksSheetView
  - Evidence (STRICT_UNUSED classification/visibility): [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/BookmarksSheetView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/BookmarksSheetView.swift#L4)
  - Evidence (Step2 file summary entry): [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/LibrarySheetScaffold.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/LibrarySheetScaffold.swift)
  - Symbol: LibrarySheetScaffold
  - Evidence (STRICT_UNUSED classification/visibility): [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/LibrarySheetScaffold.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/LibrarySheetScaffold.swift#L3)
  - Evidence (Step2 file summary entry): [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/ReadingListSheetView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/ReadingListSheetView.swift)
  - Symbol: ReadingListSheetView
  - Evidence (STRICT_UNUSED classification/visibility): [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/ReadingListSheetView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/ReadingListSheetView.swift#L4)
  - Evidence (Step2 file summary entry): [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Shared/KeyboardObserver.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Shared/KeyboardObserver.swift)
  - Symbol: KeyboardObserver
  - Evidence (STRICT_UNUSED classification/visibility): [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Shared/KeyboardObserver.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Shared/KeyboardObserver.swift#L4)
  - Evidence (Step2 file summary entry): [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv)

## Call sites to update

- None expected (STRICT_UNUSED = no production/test references).
- If build fails due to lingering file references (Xcode project), revert and defer to a dedicated Xcodeproj cleanup PR.

## Verification checklist

- `Dev/Tools/Scripts/spm.sh RuntimePackages/SafariLikeCoreKit build`
- `Dev/Tools/Scripts/xcodebuild.sh --tail 80 build`
- `Dev/Tools/Scripts/spm.sh RuntimePackages/BrowserCore test`
