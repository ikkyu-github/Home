# PR2 Dead Keys Manifest (Internal-only; no public API removals)

Evidence source:
- [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/DEAD_KEYS_REPORT.md](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/DEAD_KEYS_REPORT.md)

## Keys to remove in PR2 (internal EnvironmentValues only)

Exact files to touch:
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/LayoutStability.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/LayoutStability.swift)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Platform/Input/KeyboardHeightEnvironment.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Platform/Input/KeyboardHeightEnvironment.swift)

- isLayoutStabilizing
  - Evidence (defined but never used): [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/LayoutStability.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/LayoutStability.swift#L10)
  - Change (exact): delete `private struct IsLayoutStabilizingKey: EnvironmentKey` and remove `extension EnvironmentValues { var isLayoutStabilizing: Bool { ... } }`.
- keyboardHeight
  - Evidence (defined but never used): [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Platform/Input/KeyboardHeightEnvironment.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Platform/Input/KeyboardHeightEnvironment.swift#L11)
  - Change (exact): delete `private struct KeyboardHeightEnvironmentKey: EnvironmentKey` and remove `extension EnvironmentValues { var keyboardHeight: CGFloat { ... } }`.

## Keys deferred to PR4 (public API deprecation first)

- browserLayoutMode
  - Evidence (defined but never used): [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/BrowserLayoutEnvironment.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/BrowserLayoutEnvironment.swift#L42)
  - Reason: declared under `public extension EnvironmentValues` → treat as public API.
- browserRuntime
  - Evidence (defined but never used): [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Environment/BrowserEnvironmentKeys.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Environment/BrowserEnvironmentKeys.swift#L16)
  - Reason: declared under `public extension EnvironmentValues` → treat as public API.
- browserWindowID
  - Evidence (defined but never used): [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Environment/BrowserEnvironmentKeys.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Environment/BrowserEnvironmentKeys.swift#L11)
  - Reason: declared under `public extension EnvironmentValues` → treat as public API.
- layoutEnvironment
  - Evidence (defined but never used): [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/BrowserLayoutEnvironment.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/BrowserLayoutEnvironment.swift#L47)
  - Reason: declared under `public extension EnvironmentValues` → treat as public API.
- uxPolicy
  - Evidence (defined but never used): [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/UXPolicyEnvironment.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/UXPolicyEnvironment.swift#L8)
  - Reason: declared under `public extension EnvironmentValues` → treat as public API.

## Verification checklist

- `Dev/Tools/Scripts/spm.sh RuntimePackages/SafariLikeKit build`
- `Dev/Tools/Scripts/xcodebuild.sh --tail 80 build`
