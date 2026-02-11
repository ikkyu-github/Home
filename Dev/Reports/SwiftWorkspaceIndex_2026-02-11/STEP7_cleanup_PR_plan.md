# STEP7 — Cleanup PR Plan (Executable Sequence)

Inputs (evidence sources):
- [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STRICT_UNUSED_REPORT.md](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STRICT_UNUSED_REPORT.md)
- [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STRICT_UNUSED_REPORT.csv](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STRICT_UNUSED_REPORT.csv)
- [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/DUPLICATE_SYMBOLS_REPORT.md](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/DUPLICATE_SYMBOLS_REPORT.md)
- [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/DEAD_KEYS_REPORT.md](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/DEAD_KEYS_REPORT.md)

## Top findings (from strict reports)

- Candidates analyzed (from prior heuristic list): 120
- Confirmed UNUSED (no code references found): 100
- Public/external surface (do NOT delete): 18
- Reflective/stringly risks (do NOT delete): 1
- Tooling-limited (do NOT delete): 1
- Duplicate type names detected (broad scan): 69

Largest UNUSED clusters by module category (symbol count):
- Tests: 48
- SafariLikeKit: 35
- CoreKit: 4
- App: 4
- UNVERIFIED: 3
- UIKit: 2
- Contracts: 2
- BrowserCore: 1
- UXKit: 1

Largest UNUSED definition clusters by folder prefix (category/prefix → count):
- SafariLikeKit / RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library: 4
- Tests / RuntimePackages/BrowserCore/Tests/BrowserCoreTests/HeuristicsEngineTests.swift: 3
- SafariLikeKit / RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Tabs: 3
- SafariLikeKit / RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/StartPage: 3
- SafariLikeKit / RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Public/SafariBrowserFacade.swift: 2
- SafariLikeKit / RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager: 2
- Tests / RuntimePackages/SafariLikeUXKit/Tests/SafariLikeUXKitTests/AddressBarFeatureTests.swift: 1
- CoreKit / RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/AddressBar/AddressBarReducer.swift: 1
- UNVERIFIED / RuntimePackages/SafariLikeUXKit/Tests/AddressBarStateMachineTests.swift: 1
- App / App/AppRootView.swift: 1

Biggest duplicate-name collision groups (top 10 by definition count; TOOLING-LIMITED for binding):
- State: 12 defs (BrowserCore, CoreKit, SafariLikeKit, UXKit)
- Configuration: 10 defs (BrowserCore, SafariLikeKit, UXKit)
- Input: 9 defs (BrowserCore, SafariLikeKit)
- CodingKeys: 8 defs (BrowserCore, Contracts, SafariLikeKit)
- Kind: 7 defs (Contracts, CoreKit, SafariLikeKit)
- Decision: 6 defs (BrowserCore, SafariLikeKit)
- Coordinator: 5 defs (SafariLikeKit)
- Snapshot: 5 defs (CoreKit, SafariLikeKit, UXKit)
- Event: 4 defs (CoreKit, SafariLikeKit, UXKit)
- MemoryPressureLevel: 4 defs (BrowserCore, Contracts, CoreKit, SafariLikeKit)

Dead key categories (STRICT literal-based):
- UserDefaults/AppStorage keys written but never read: 0
- UserDefaults/AppStorage keys read but never written: 0
- Notification.Name literals posted but never observed: 0
- Notification.Name literals observed but never posted: 0
- EnvironmentValues keys defined but never used: 7
- EnvironmentValues keys used but no definition found (TOOLING-LIMITED): 0

## PR sequence (order matters)

### PR0 — Safety rails (no functional changes)
Title: Cleanup safety rails + verification checklist

Scope constraints:
- Allowed: documentation only (rules, checklists).
- Not allowed: deleting/renaming Swift symbols; changing runtime behavior.

Files to touch:
- [Docs/CLEANUP_RULES.md](Docs/CLEANUP_RULES.md) (new)
- [Docs/CLEANUP_VERIFICATION_CHECKLIST.md](Docs/CLEANUP_VERIFICATION_CHECKLIST.md) (new)

Verification checklist:
- `Dev/Tools/Scripts/xcodebuild.sh --tail 80 build`
- `Dev/Tools/Scripts/spm.sh RuntimePackages/BrowserCore test`
- Optional: run UI tests target (Xcode scheme)

Rollback strategy:
- Revert docs-only commit.

### PR1 — Remove confirmed UNUSED internal/private (lowest risk; production Sources only; batch 1)
Title: Delete confirmed-unused internal/private files (batch 1)

Scope constraints:
- Allowed: delete entire Swift files under `RuntimePackages/**/Sources/**` only when file contains exactly one confirmed-unused internal/private type and no functions/extensions (per Step2 summary).
- Not allowed: deleting App target files (requires Xcode project edits); deleting anything classified PUBLIC-API/EXTERNAL, REFLECTIVE/STRINGLY-RISK, or TOOLING-LIMITED.
- Not allowed: deleting files under `RuntimePackages/**/Tests/**` in this PR (keep PR small).

Evidence:
- [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STRICT_UNUSED_REPORT.csv](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STRICT_UNUSED_REPORT.csv) (classification + visibility)
- [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP2_per_file_summary.csv) (file contains only that type; no functions/extensions)

Changeset:
- See [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP7_PR1_deletion_manifest.md](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP7_PR1_deletion_manifest.md)

Exact files to touch (delete):
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/SplitFeatureFlags.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/SplitFeatureFlags.swift)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/AppLifecyclePhase.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/AppLifecyclePhase.swift)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/Controllers/TabSelectionTransaction.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/Controllers/TabSelectionTransaction.swift)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/SplitBrowser/State/SplitBrowserState.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/SplitBrowser/State/SplitBrowserState.swift)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/State/LayoutState.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/State/LayoutState.swift)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/State/NavigationState.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/State/NavigationState.swift)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Chrome/BrowserChromeView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Chrome/BrowserChromeView.swift)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/PrimaryPane.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/PrimaryPane.swift)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/BookmarksSheetView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/BookmarksSheetView.swift)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/LibrarySheetScaffold.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/LibrarySheetScaffold.swift)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/ReadingListSheetView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/ReadingListSheetView.swift)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Shared/KeyboardObserver.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Shared/KeyboardObserver.swift)

Verification checklist:
- `Dev/Tools/Scripts/xcodebuild.sh --tail 80 build`
- `Dev/Tools/Scripts/spm.sh RuntimePackages/SafariLikeCoreKit build`
- `Dev/Tools/Scripts/spm.sh RuntimePackages/BrowserCore test`

Rollback strategy:
- Revert the PR commit(s); deleted files restore cleanly.

### PR2 — Dead keys cleanup (no behavior change; internal-only keys)
Title: Remove dead internal EnvironmentValues keys

Scope constraints:
- Allowed: remove EnvironmentKey + EnvironmentValues var that are internal (non-public extension) and confirmed-unused in dead-keys report.
- Not allowed: removing keys declared in `public extension EnvironmentValues` (treat as public API; defer to PR4 deprecation).

Evidence:
- [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/DEAD_KEYS_REPORT.md](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/DEAD_KEYS_REPORT.md) (defined-but-never-used)

Changeset:
- See [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP7_PR2_dead_keys_manifest.md](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP7_PR2_dead_keys_manifest.md)

Exact files to touch:
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/LayoutStability.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/LayoutStability.swift)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Platform/Input/KeyboardHeightEnvironment.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Platform/Input/KeyboardHeightEnvironment.swift)

Verification checklist:
- `Dev/Tools/Scripts/xcodebuild.sh --tail 80 build`
- `Dev/Tools/Scripts/spm.sh RuntimePackages/SafariLikeKit build`

Rollback strategy:
- Revert the PR commit(s); keys can be restored without migrations.

### PR3 — Duplicate symbol shadowing resolution (refactor-lite; guardrails + disambiguation)
Title: Add duplicate-name disambiguation guardrails (no API breaks)

Scope constraints:
- Allowed: add tests/guards to ensure cross-module duplicates are always referenced with explicit module qualification in any file that imports both modules.
- Not allowed: renaming or deleting public types (requires deprecation plan; handled in PR4).
- Not allowed: deleting anything TOOLING-LIMITED.

Evidence:
- [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/DUPLICATE_SYMBOLS_REPORT.md](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/DUPLICATE_SYMBOLS_REPORT.md) (collision groups)
- [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STRICT_UNUSED_REPORT.csv](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STRICT_UNUSED_REPORT.csv) (BrowserSession TOOLING-LIMITED due to duplicate definitions)

Direct evidence links (duplicate definitions):
- BrowserSession:
	- [RuntimePackages/BrowserCore/Sources/BrowserCore/Models/BrowserSession.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Models/BrowserSession.swift#L2)
	- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Session/BrowserSession.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Session/BrowserSession.swift#L29)
- ChromeEvent:
	- [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Chrome/ChromeViewContracts.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Chrome/ChromeViewContracts.swift#L6)
	- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Chrome/ChromeTypes.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Chrome/ChromeTypes.swift#L9)
	- [RuntimePackages/SafariLikeUXKit/Chrome/ChromeStateMachine.swift](RuntimePackages/SafariLikeUXKit/Chrome/ChromeStateMachine.swift#L5)
- ChromeViewState:
	- [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Chrome/ChromeViewContracts.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Chrome/ChromeViewContracts.swift#L15)
	- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Chrome/ChromeTypes.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Chrome/ChromeTypes.swift#L2)
	- [RuntimePackages/SafariLikeUXKit/Chrome/ChromeStateMachine.swift](RuntimePackages/SafariLikeUXKit/Chrome/ChromeStateMachine.swift#L16)

Changeset:
- See [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP7_PR3_duplicate_symbols_manifest.md](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP7_PR3_duplicate_symbols_manifest.md)

Exact files to touch:
- [RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/DuplicateNameDisambiguationTests.swift](RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/DuplicateNameDisambiguationTests.swift) (new)
- [Scripts/check_duplicate_name_disambiguation.sh](Scripts/check_duplicate_name_disambiguation.sh) (new, optional)

Verification checklist:
- `Dev/Tools/Scripts/xcodebuild.sh --tail 80 build`
- `Dev/Tools/Scripts/spm.sh RuntimePackages/SafariLikeKit test` (if available)

Rollback strategy:
- Revert guardrail changes; no runtime state impact.

### PR4 — Public/external surface deprecation (no deletions yet)
Title: Deprecate unused public APIs (no removals)

Scope constraints:
- Allowed: add `@available(*, deprecated, message: ...)` to PUBLIC-API/EXTERNAL items; add migration notes.
- Not allowed: deleting deprecated APIs yet.

Evidence:
- [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STRICT_UNUSED_REPORT.csv](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STRICT_UNUSED_REPORT.csv) (PUBLIC-API/EXTERNAL classification)
- [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/DEAD_KEYS_REPORT.md](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/DEAD_KEYS_REPORT.md) (public EnvironmentValues keys defined-but-never-used; deprecate instead of delete)

Verification checklist:
- `Dev/Tools/Scripts/xcodebuild.sh --tail 80 build`

### PR5 — TOOLING-LIMITED follow-up (validation plan)
Title: Add USR-based reference validation (SourceKit) or targeted integration builds

Scope constraints:
- Allowed: add scripts/docs to run SourceKit-LSP based indexing or Xcode index queries; re-run strict analysis in MODE B when tooling becomes available.
- Not allowed: deleting TOOLING-LIMITED items before validation.

Concrete validation steps:
- Install `sourcekitten` and/or `swift-index` (if acceptable) and re-run strict unused analysis with USR resolution.
- Otherwise: for each TOOLING-LIMITED item, run a dedicated `rg`/AST scan for module-qualified references and create a per-item validation note.

## Risk register

- See [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP7_risk_register.md](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP7_risk_register.md)
