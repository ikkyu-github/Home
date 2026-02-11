# STEP7 Risk Register (Deletion/Refactor Safety)

Evidence sources:
- [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STRICT_UNUSED_REPORT.csv](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STRICT_UNUSED_REPORT.csv)
- [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/DEAD_KEYS_REPORT.md](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/DEAD_KEYS_REPORT.md)
- [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/DUPLICATE_SYMBOLS_REPORT.md](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/DUPLICATE_SYMBOLS_REPORT.md)

## Public/external surface (do NOT delete; PR4 deprecate first)

- AccessibilityPreferenceSnapshot (SafariLikeContracts / Contracts)
  - Evidence: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Commands/AccessibilityPreferenceSnapshot.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Commands/AccessibilityPreferenceSnapshot.swift#L7)
- BottomSheetView (SafariLikeUXKit / UXKit)
  - Evidence: [RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/Overview/BottomSheetView.swift](RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/Overview/BottomSheetView.swift#L6)
- BrowserSplitContainer (SafariLikeKit / SafariLikeKit)
  - Evidence: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Views/Layout/BrowserSplitContainer.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Views/Layout/BrowserSplitContainer.swift#L3)
- CrossSceneIntent (SafariLikeContracts / Contracts)
  - Evidence: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Scenes/SceneContracts.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Scenes/SceneContracts.swift#L46)
- DownloadDestinationPolicy (BrowserCore / BrowserCore)
  - Evidence: [RuntimePackages/BrowserCore/Sources/BrowserCore/Downloads/DownloadDestinationPolicy.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Downloads/DownloadDestinationPolicy.swift#L7)
- LibraryService (BrowserCore / BrowserCore)
  - Evidence: [RuntimePackages/BrowserCore/Sources/BrowserCore/Library/LibraryService.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Library/LibraryService.swift#L5)
- MemoryPressureNotifying (SafariLikeCoreKit / CoreKit)
  - Evidence: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Protocols/MemoryPressureNotifying.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Protocols/MemoryPressureNotifying.swift#L6)
- RotationTransitionObserverView (SafariLikeKit / SafariLikeKit)
  - Evidence: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Scene/RotationTransitionObserverView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Scene/RotationTransitionObserverView.swift#L7)
- SandboxedPolicyProvider (SafariLikeKit / SafariLikeKit)
  - Evidence: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Plugins/Boundary/PluginSandbox.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Plugins/Boundary/PluginSandbox.swift#L17)
- ScriptExecutionRecord (SafariLikeContracts / Contracts)
  - Evidence: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/UserScripts/UserScriptModels.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/UserScripts/UserScriptModels.swift#L157)
- SessionRestorer (BrowserCore / BrowserCore)
  - Evidence: [RuntimePackages/BrowserCore/Sources/BrowserCore/Session/Journal/SessionRestorer.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Session/Journal/SessionRestorer.swift#L18)
- SettingsDeepLink (SafariLikeContracts / Contracts)
  - Evidence: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Autofill/AutofillModels.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Autofill/AutofillModels.swift#L61)
- SharePayload (SafariLikeContracts / Contracts)
  - Evidence: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Downloads/DownloadsModels.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Downloads/DownloadsModels.swift#L140)
- SnapshotProviding (SafariLikeCoreKit / CoreKit)
  - Evidence: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Protocols/SnapshotProviding.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Protocols/SnapshotProviding.swift#L5)
- TabEffect (SafariLikeKit / SafariLikeKit)
  - Evidence: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/StateMachine/TabEffects.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/StateMachine/TabEffects.swift#L3)
- TabReducer (SafariLikeKit / SafariLikeKit)
  - Evidence: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/StateMachine/TabReducer.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/StateMachine/TabReducer.swift#L3)
- UserInfoKey (SafariLikeCoreKit / CoreKit)
  - Evidence: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Diagnostics/WebViewLifecycleDebugNotifications.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Diagnostics/WebViewLifecycleDebugNotifications.swift#L11)
- WindowReducer (SafariLikeKit / SafariLikeKit)
  - Evidence: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/StateMachine/WindowReducer.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/StateMachine/WindowReducer.swift#L3)

## Reflective/stringly risks (do NOT delete without deeper analysis)

- CompanionPane (SafariLikeKit / SafariLikeKit)
  - Evidence: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/CompanionPane.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/CompanionPane.swift#L3)
  - Risk notes: type name appears in string literals

## Tooling-limited items (do NOT delete)

- BrowserSession
  - Evidence: [RuntimePackages/BrowserCore/Sources/BrowserCore/Models/BrowserSession.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Models/BrowserSession.swift#L2), [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Session/BrowserSession.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Session/BrowserSession.swift#L29)
  - Reason: duplicate definitions across modules/categories

## Dead keys that are public API (deprecate first; do NOT delete in PR2)

- browserLayoutMode
  - Evidence: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/BrowserLayoutEnvironment.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/BrowserLayoutEnvironment.swift#L42)
  - Risk: declared under `public extension EnvironmentValues` → potential downstream usage.
- browserRuntime
  - Evidence: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Environment/BrowserEnvironmentKeys.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Environment/BrowserEnvironmentKeys.swift#L16)
  - Risk: declared under `public extension EnvironmentValues` → potential downstream usage.
- browserWindowID
  - Evidence: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Environment/BrowserEnvironmentKeys.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Environment/BrowserEnvironmentKeys.swift#L11)
  - Risk: declared under `public extension EnvironmentValues` → potential downstream usage.
- layoutEnvironment
  - Evidence: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/BrowserLayoutEnvironment.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/BrowserLayoutEnvironment.swift#L47)
  - Risk: declared under `public extension EnvironmentValues` → potential downstream usage.
- uxPolicy
  - Evidence: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/UXPolicyEnvironment.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/UXPolicyEnvironment.swift#L8)
  - Risk: declared under `public extension EnvironmentValues` → potential downstream usage.

## Duplicate symbol report limitations

- Duplicate name groups include nested types; they do not necessarily cause module-level collisions.
- Binding correctness requires USR-level indexing (PR5) or per-use-site qualification audit.
