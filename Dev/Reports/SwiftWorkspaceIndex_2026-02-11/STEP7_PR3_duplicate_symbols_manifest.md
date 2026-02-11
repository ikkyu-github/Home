# PR3 Duplicate Symbols Manifest (Guardrails + disambiguation; no API breaks)

Why this PR is guardrails-first:
- The duplicate symbol report is TOOLING-LIMITED for binding (no USR index), and includes many nested types that do not collide at module scope.
- Public type renames/deletions require PR4 deprecation strategy.

## Collision focus set

- BrowserSession
  - Why: Duplicate group; also TOOLING-LIMITED in strict unused
  - Evidence (strict tooling-limited): [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STRICT_UNUSED_REPORT.csv](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STRICT_UNUSED_REPORT.csv)
  - Evidence (duplicate definitions):
    - [RuntimePackages/BrowserCore/Sources/BrowserCore/Models/BrowserSession.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Models/BrowserSession.swift#L2)
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Session/BrowserSession.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Session/BrowserSession.swift#L29)
- ChromeViewState
  - Why: Duplicate group across Contracts/Kit/UXKit
  - Evidence (duplicate definitions):
    - [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Chrome/ChromeViewContracts.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Chrome/ChromeViewContracts.swift#L15)
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Chrome/ChromeTypes.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Chrome/ChromeTypes.swift#L2)
    - [RuntimePackages/SafariLikeUXKit/Chrome/ChromeStateMachine.swift](RuntimePackages/SafariLikeUXKit/Chrome/ChromeStateMachine.swift#L16)
- ChromeEvent
  - Why: Duplicate group across Contracts/Kit/UXKit
  - Evidence (duplicate definitions):
    - [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Chrome/ChromeViewContracts.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Chrome/ChromeViewContracts.swift#L6)
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Chrome/ChromeTypes.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Chrome/ChromeTypes.swift#L9)
    - [RuntimePackages/SafariLikeUXKit/Chrome/ChromeStateMachine.swift](RuntimePackages/SafariLikeUXKit/Chrome/ChromeStateMachine.swift#L5)

## Changes to make in PR3

- Add a new Swift test file that imports multiple modules and forces module-qualified references for known-collision names.
  - New file: [RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/DuplicateNameDisambiguationTests.swift](RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/DuplicateNameDisambiguationTests.swift)
  - Contents (requirements):
    - `import SafariLikeKit`
    - `import BrowserCore`
    - `import SafariLikeContracts`
    - Assert the compiler can resolve `BrowserCore.BrowserSession` vs `SafariLikeKit.BrowserSession`.
    - Assert the compiler can resolve `SafariLikeContracts.ChromeViewState` vs `SafariLikeKit.ChromeViewState`.
- (Optional) Add a lightweight repo_guard rule that fails CI if a file imports both modules and uses an unqualified collision name.
  - Candidate script: [Scripts/check_duplicate_name_disambiguation.sh](Scripts/check_duplicate_name_disambiguation.sh) (new)

## Call sites to update

- None in this PR (guardrails only).
- Follow-up: if guardrails reveal ambiguous files, update them to module-qualify the symbol at the use site.

## Verification checklist

- `Dev/Tools/Scripts/spm.sh RuntimePackages/SafariLikeKit test`
- `Dev/Tools/Scripts/xcodebuild.sh --tail 80 build`
