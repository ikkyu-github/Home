# STRICT Unused/Reference Report

Mode: MODE A (strict text-based; no USR index)

Strictness policy:
- Reference scans run on code-only text (comments and string literals excluded).
- Definition lines and `extension TypeName` lines are excluded as references.
- Any external/public surface or reflective risk is not classified as UNUSED.

## Confirmed UNUSED (no code references found) (100)

- AddressBarFeatureTests (SafariLikeUXKitTests / Tests)
  - Targets: SafariLikeUXKitTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeUXKit/Tests/SafariLikeUXKitTests/AddressBarFeatureTests.swift](RuntimePackages/SafariLikeUXKit/Tests/SafariLikeUXKitTests/AddressBarFeatureTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bAddressBarFeatureTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- AddressBarReducer (SafariLikeCoreKit / CoreKit)
  - Targets: SafariLikeCoreKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/AddressBar/AddressBarReducer.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/AddressBar/AddressBarReducer.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bAddressBarReducer\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- AddressBarStateMachineTests (UNVERIFIED / UNVERIFIED)
  - Targets: UNVERIFIED
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeUXKit/Tests/AddressBarStateMachineTests.swift](RuntimePackages/SafariLikeUXKit/Tests/AddressBarStateMachineTests.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bAddressBarStateMachineTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- AppBrowserSessionProvider (webOS / App)
  - Targets: UNVERIFIED
  - Visibility: internal
  - Definition(s):
    - [App/AppRootView.swift](App/AppRootView.swift#L5)
  - Reference search (STRICT):
    - Patterns: `\bAppBrowserSessionProvider\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- AppLifecyclePhase (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/AppLifecyclePhase.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/AppLifecyclePhase.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bAppLifecyclePhase\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- AppSettingsStore (webOS / App)
  - Targets: UNVERIFIED
  - Visibility: internal
  - Definition(s):
    - [App/AppSettingsStore.swift](App/AppSettingsStore.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bAppSettingsStore\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- AttachmentInvariantTests (SafariLikeKitTests / Tests)
  - Targets: SafariLikeKitTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/AttachmentInvariantTests.swift](RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/AttachmentInvariantTests.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bAttachmentInvariantTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- BookmarksSheetView (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/BookmarksSheetView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/BookmarksSheetView.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bBookmarksSheetView\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- BrowserChromeView (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Chrome/BrowserChromeView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Chrome/BrowserChromeView.swift#L5)
  - Reference search (STRICT):
    - Patterns: `\bBrowserChromeView\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- BrowserCoordinatorImpl (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Coordinator.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Coordinator.swift#L6)
  - Reference search (STRICT):
    - Patterns: `\bBrowserCoordinatorImpl\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- BrowserLayoutModeDerivationTests (SafariLikeKitTests / Tests)
  - Targets: SafariLikeKitTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/BrowserLayoutModeDerivationTests.swift](RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/BrowserLayoutModeDerivationTests.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bBrowserLayoutModeDerivationTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- BrowserLog (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: private
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Views/SafariLikeKitCoreBrowserLog.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Views/SafariLikeKitCoreBrowserLog.swift#L5)
  - Reference search (STRICT):
    - Patterns: `\bBrowserLog\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- BrowserSessionStoreNavigationTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/BrowserSessionStoreNavigationTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/BrowserSessionStoreNavigationTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bBrowserSessionStoreNavigationTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- BrowserSessionStoreTabManagementTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/BrowserSessionStoreTabManagementTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/BrowserSessionStoreTabManagementTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bBrowserSessionStoreTabManagementTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- BrowserUXStateTests (SafariLikeKitTests / Tests)
  - Targets: SafariLikeKitTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/BrowserUXStateTests.swift](RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/BrowserUXStateTests.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bBrowserUXStateTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- ChromePolicyController (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/ChromePolicyController.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/ChromePolicyController.swift#L5)
  - Reference search (STRICT):
    - Patterns: `\bChromePolicyController\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- ChromeScrollCouplingTests (SafariLikeUIKitTests / Tests)
  - Targets: SafariLikeUIKitTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeUIKit/Tests/SafariLikeUIKitTests/ChromeScrollCouplingTests.swift](RuntimePackages/SafariLikeUIKit/Tests/SafariLikeUIKitTests/ChromeScrollCouplingTests.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bChromeScrollCouplingTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- ChromeStateMachineTests (UNVERIFIED / UNVERIFIED)
  - Targets: UNVERIFIED
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeUXKit/Tests/ChromeStateMachineTests.swift](RuntimePackages/SafariLikeUXKit/Tests/ChromeStateMachineTests.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bChromeStateMachineTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- ClearDataTimeRangeTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/ClearDataTimeRangeTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/ClearDataTimeRangeTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bClearDataTimeRangeTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- CompanionListView_Previews (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Companion/CompanionListView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Companion/CompanionListView.swift#L397)
  - Reference search (STRICT):
    - Patterns: `\bCompanionListView_Previews\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- DebugLayoutOverlay (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Diagnostics/DebugLayoutOverlay.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Diagnostics/DebugLayoutOverlay.swift#L5)
  - Reference search (STRICT):
    - Patterns: `\bDebugLayoutOverlay\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- ExampleViewController (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Plugins/Runtime/PluginHostExample.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Plugins/Runtime/PluginHostExample.swift#L11)
  - Reference search (STRICT):
    - Patterns: `\bExampleViewController\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- FormFillPolicyEngineTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/FormFillPolicyEngineTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/FormFillPolicyEngineTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bFormFillPolicyEngineTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- HeuristicsEngineTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/HeuristicsEngineTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/HeuristicsEngineTests.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bHeuristicsEngineTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- HistoryEngineTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/Library/HistoryEngineTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/Library/HistoryEngineTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bHistoryEngineTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- HistorySheetView (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/HistorySheetView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/HistorySheetView.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bHistorySheetView\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- InvariantEnforcerTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/InvariantEnforcerTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/InvariantEnforcerTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bInvariantEnforcerTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- KeyboardObserver (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Shared/KeyboardObserver.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Shared/KeyboardObserver.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bKeyboardObserver\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- LayoutState (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/State/LayoutState.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/State/LayoutState.swift#L5)
  - Reference search (STRICT):
    - Patterns: `\bLayoutState\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- LibrarySheetScaffold (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/LibrarySheetScaffold.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/LibrarySheetScaffold.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bLibrarySheetScaffold\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- LoggerFactory (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Logging/LoggerFactory.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Logging/LoggerFactory.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bLoggerFactory\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- NavigationState (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/State/NavigationState.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/State/NavigationState.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bNavigationState\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- OmnibarStateMachineTests (SafariLikeUIKitTests / Tests)
  - Targets: SafariLikeUIKitTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeUIKit/Tests/SafariLikeUIKitTests/OmnibarStateMachineTests.swift](RuntimePackages/SafariLikeUIKit/Tests/SafariLikeUIKitTests/OmnibarStateMachineTests.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bOmnibarStateMachineTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- OmnibarView (SafariLikeUIKit / UIKit)
  - Targets: SafariLikeUIKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit/Omnibar/OmnibarView.swift](RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit/Omnibar/OmnibarView.swift#L2)
  - Reference search (STRICT):
    - Patterns: `\bOmnibarView\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- OmniboxParserTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/OmniboxParserTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/OmniboxParserTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bOmniboxParserTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- PaneRole (SafariLikeCoreKit / CoreKit)
  - Targets: SafariLikeCoreKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Policy/PaneLayout.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Policy/PaneLayout.swift#L2)
  - Reference search (STRICT):
    - Patterns: `\bPaneRole\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- PaneVisibilityCoordinator (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Lifecycle/PaneVisibilityCoordinator.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Lifecycle/PaneVisibilityCoordinator.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bPaneVisibilityCoordinator\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- ParityAuditRunnerTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/ParityAuditRunnerTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/ParityAuditRunnerTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bParityAuditRunnerTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- PhysicsTuning (SafariLikeUIKit / UIKit)
  - Targets: SafariLikeUIKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit/Physics/PhysicsTuning.swift](RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit/Physics/PhysicsTuning.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bPhysicsTuning\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- PluginAuditLogger (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Plugins/Core/PluginAuditLogger.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Plugins/Core/PluginAuditLogger.swift#L5)
  - Reference search (STRICT):
    - Patterns: `\bPluginAuditLogger\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- PluginEnablementStoreTests (SafariLikeKitTests / Tests)
  - Targets: SafariLikeKitTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/PluginEnablementStoreTests.swift](RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/PluginEnablementStoreTests.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bPluginEnablementStoreTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- PoolKey (SafariLikeCoreKit / CoreKit)
  - Targets: SafariLikeCoreKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Engine/EngineController.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Engine/EngineController.swift#L36)
  - Reference search (STRICT):
    - Patterns: `\bPoolKey\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- PrimaryPane (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/PrimaryPane.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/PrimaryPane.swift#L5)
  - Reference search (STRICT):
    - Patterns: `\bPrimaryPane\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- PrivacyReportEngineTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/PrivacyReportEngineTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/PrivacyReportEngineTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bPrivacyReportEngineTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- Radius (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/BrowserConstants.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/BrowserConstants.swift#L35)
  - Reference search (STRICT):
    - Patterns: `\bRadius\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- ReaderModeController (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Platform/Web/Reader/ReaderModeController.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Platform/Web/Reader/ReaderModeController.swift#L5)
  - Reference search (STRICT):
    - Patterns: `\bReaderModeController\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- ReaderModeEngine (BrowserCore / BrowserCore)
  - Targets: BrowserCore
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Sources/BrowserCore/Reader/ReaderModeEngine.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Reader/ReaderModeEngine.swift#L8)
  - Reference search (STRICT):
    - Patterns: `\bReaderModeEngine\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- ReadingListSheetView (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/ReadingListSheetView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Library/ReadingListSheetView.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bReadingListSheetView\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- RelatedPresentationSuppressionTests (SafariLikeKitTests / Tests)
  - Targets: SafariLikeKitTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/RelatedPresentationSuppressionTests.swift](RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/RelatedPresentationSuppressionTests.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bRelatedPresentationSuppressionTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- RelatedUIState (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Related/RelatedUIState.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Related/RelatedUIState.swift#L9)
  - Reference search (STRICT):
    - Patterns: `\bRelatedUIState\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- RenderBudgetPolicyTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/RenderBudgetPolicyTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/RenderBudgetPolicyTests.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bRenderBudgetPolicyTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- ResolvedInsetsProviderTests (SafariLikeKitTests / Tests)
  - Targets: SafariLikeKitTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/ResolvedInsetsProviderTests.swift](RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/ResolvedInsetsProviderTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bResolvedInsetsProviderTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- RotationRegressionUITests (UNVERIFIED / Tests)
  - Targets: UNVERIFIED
  - Visibility: internal
  - Definition(s):
    - [webOSUITests/RotationRegressionUITests.swift](webOSUITests/RotationRegressionUITests.swift#L2)
  - Reference search (STRICT):
    - Patterns: `\bRotationRegressionUITests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SafariBrowserConfiguration (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Public/SafariBrowserFacade.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Public/SafariBrowserFacade.swift#L9)
  - Reference search (STRICT):
    - Patterns: `\bSafariBrowserConfiguration\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SafariBrowserSession (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Public/SafariBrowserFacade.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Public/SafariBrowserFacade.swift#L5)
  - Reference search (STRICT):
    - Patterns: `\bSafariBrowserSession\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SafariEdgeGestureLayerPane (SafariLikeUXKit / UXKit)
  - Targets: SafariLikeUXKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/Gestures/SafariEdgeGestureLayerPane.swift](RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/Gestures/SafariEdgeGestureLayerPane.swift#L2)
  - Reference search (STRICT):
    - Patterns: `\bSafariEdgeGestureLayerPane\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SafariTabLandscapeGrid (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Tabs/Components/SafariTabStacks.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Tabs/Components/SafariTabStacks.swift#L38)
  - Reference search (STRICT):
    - Patterns: `\bSafariTabLandscapeGrid\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SafariTabPortraitStack (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Tabs/Components/SafariTabStacks.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Tabs/Components/SafariTabStacks.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bSafariTabPortraitStack\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SceneCommandRouterTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/SceneCommandRouterTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/SceneCommandRouterTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bSceneCommandRouterTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SceneMetricsTests (SafariLikeKitTests / Tests)
  - Targets: SafariLikeKitTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/SceneMetricsTests.swift](RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/SceneMetricsTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bSceneMetricsTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SceneMultiIsolationAndLeakTests (SafariLikeKitTests / Tests)
  - Targets: SafariLikeKitTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/SceneMultiIsolationAndLeakTests.swift](RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/SceneMultiIsolationAndLeakTests.swift#L5)
  - Reference search (STRICT):
    - Patterns: `\bSceneMultiIsolationAndLeakTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SceneMultiIsolationTests (SafariLikeCoreKitTests / Tests)
  - Targets: SafariLikeCoreKitTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeCoreKit/Tests/SafariLikeCoreKitTests/SceneMultiIsolationTests.swift](RuntimePackages/SafariLikeCoreKit/Tests/SafariLikeCoreKitTests/SceneMultiIsolationTests.swift#L5)
  - Reference search (STRICT):
    - Patterns: `\bSceneMultiIsolationTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SceneRuntimeIsolationTests (SafariLikeKitTests / Tests)
  - Targets: SafariLikeKitTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/SceneRuntimeIsolationTests.swift](RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/SceneRuntimeIsolationTests.swift#L7)
  - Reference search (STRICT):
    - Patterns: `\bSceneRuntimeIsolationTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- ScriptPolicyEngineTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/UserScripts/ScriptPolicyEngineTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/UserScripts/ScriptPolicyEngineTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bScriptPolicyEngineTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SearchProfile (SafariLikeContracts / Contracts)
  - Targets: SafariLikeContracts
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Search/SearchEngineModels.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Search/SearchEngineModels.swift#L37)
  - Reference search (STRICT):
    - Patterns: `\bSearchProfile\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SearchURLBuilderTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/SearchURLBuilderTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/SearchURLBuilderTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bSearchURLBuilderTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SessionJournalTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/SessionJournalTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/SessionJournalTests.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bSessionJournalTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SessionReplayDeterminismTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/SessionReplayDeterminismTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/SessionReplayDeterminismTests.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bSessionReplayDeterminismTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SessionReplayEngineTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/SessionReplayEngineTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/SessionReplayEngineTests.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bSessionReplayEngineTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SettingsSection (webOS / App)
  - Targets: UNVERIFIED
  - Visibility: internal
  - Definition(s):
    - [App/Views/SettingsMenuModel.swift](App/Views/SettingsMenuModel.swift#L6)
  - Reference search (STRICT):
    - Patterns: `\bSettingsSection\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SettingsView (webOS / App)
  - Targets: UNVERIFIED
  - Visibility: internal
  - Definition(s):
    - [App/Views/SettingsView.swift](App/Views/SettingsView.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bSettingsView\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- ShareCoordinatorTests (SafariLikeKitTests / Tests)
  - Targets: SafariLikeKitTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/ShareCoordinatorTests.swift](RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/ShareCoordinatorTests.swift#L6)
  - Reference search (STRICT):
    - Patterns: `\bShareCoordinatorTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SiteHeuristicsModelTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/HeuristicsEngineTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/HeuristicsEngineTests.swift#L185)
  - Reference search (STRICT):
    - Patterns: `\bSiteHeuristicsModelTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SitePolicyTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/HeuristicsEngineTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/HeuristicsEngineTests.swift#L230)
  - Reference search (STRICT):
    - Patterns: `\bSitePolicyTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SiteSettingsStoreTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/SiteSettingsStoreTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/SiteSettingsStoreTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bSiteSettingsStoreTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SnapshotServiceTests (SafariLikeKitTests / Tests)
  - Targets: SafariLikeKitTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/SnapshotServiceTests.swift](RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/SnapshotServiceTests.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bSnapshotServiceTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SplitBrowserCoordinator (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/SplitBrowser/Coordinator/SplitBrowserCoordinator.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/SplitBrowser/Coordinator/SplitBrowserCoordinator.swift#L5)
  - Reference search (STRICT):
    - Patterns: `\bSplitBrowserCoordinator\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SplitBrowserState (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/SplitBrowser/State/SplitBrowserState.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/SplitBrowser/State/SplitBrowserState.swift#L6)
  - Reference search (STRICT):
    - Patterns: `\bSplitBrowserState\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SplitFeatureFlags (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/SplitFeatureFlags.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/SplitFeatureFlags.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bSplitFeatureFlags\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- StartPageFavoritesGrid (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/StartPage/StartPageFavoritesGrid.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/StartPage/StartPageFavoritesGrid.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bStartPageFavoritesGrid\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- StartPageSearchBar (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/StartPage/StartPageSearchBar.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/StartPage/StartPageSearchBar.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bStartPageSearchBar\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- StartPageView (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/StartPage/StartPageView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/StartPage/StartPageView.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bStartPageView\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- StaticSharedGateTests (UNVERIFIED / UNVERIFIED)
  - Targets: UNVERIFIED
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Tests/StaticSharedGateTests.swift](RuntimePackages/SafariLikeKit/Tests/StaticSharedGateTests.swift#L2)
  - Reference search (STRICT):
    - Patterns: `\bStaticSharedGateTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- SuggestionsEngineTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/Library/SuggestionsEngineTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/Library/SuggestionsEngineTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bSuggestionsEngineTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- TabChromeUITests (UNVERIFIED / Tests)
  - Targets: UNVERIFIED
  - Visibility: internal
  - Definition(s):
    - [webOSUITests/TabChromeUITests.swift](webOSUITests/TabChromeUITests.swift#L2)
  - Reference search (STRICT):
    - Patterns: `\bTabChromeUITests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- TabDiscardController (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/Components/TabDiscardController.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/Components/TabDiscardController.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bTabDiscardController\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- TabDiscardPolicyTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/TabDiscardPolicyTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/TabDiscardPolicyTests.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bTabDiscardPolicyTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- TabManagerRegressionTests (SafariLikeKitTests / Tests)
  - Targets: SafariLikeKitTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/TabManagerRegressionTests.swift](RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/TabManagerRegressionTests.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bTabManagerRegressionTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- TabNavigationReducerTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/TabNavigationReducerTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/TabNavigationReducerTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bTabNavigationReducerTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- TabRegistryBudgetTests (SafariLikeCoreKitTests / Tests)
  - Targets: SafariLikeCoreKitTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeCoreKit/Tests/SafariLikeCoreKitTests/TabRegistryBudgetTests.swift](RuntimePackages/SafariLikeCoreKit/Tests/SafariLikeCoreKitTests/TabRegistryBudgetTests.swift#L5)
  - Reference search (STRICT):
    - Patterns: `\bTabRegistryBudgetTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- TabResourcePolicyTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/TabResourcePolicyTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/TabResourcePolicyTests.swift#L6)
  - Reference search (STRICT):
    - Patterns: `\bTabResourcePolicyTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- TabSelectionTransaction (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/Controllers/TabSelectionTransaction.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/Controllers/TabSelectionTransaction.swift#L6)
  - Reference search (STRICT):
    - Patterns: `\bTabSelectionTransaction\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- TabStripView_Previews (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Tabs/TabStripView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Tabs/TabStripView.swift#L40)
  - Reference search (STRICT):
    - Patterns: `\bTabStripView_Previews\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- TabWebStoreLifecycleTests (SafariLikeCoreKitTests / Tests)
  - Targets: SafariLikeCoreKitTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeCoreKit/Tests/SafariLikeCoreKitTests/TabWebStoreLifecycleTests.swift](RuntimePackages/SafariLikeCoreKit/Tests/SafariLikeCoreKitTests/TabWebStoreLifecycleTests.swift#L11)
  - Reference search (STRICT):
    - Patterns: `\bTabWebStoreLifecycleTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- TelemetryEngineTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/TelemetryEngineTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/TelemetryEngineTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bTelemetryEngineTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- TopSitesEngineTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/Library/TopSitesEngineTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/Library/TopSitesEngineTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bTopSitesEngineTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- URLStringNormalizerTests (BrowserCoreTests / Tests)
  - Targets: BrowserCoreTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/Library/URLStringNormalizerTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/Library/URLStringNormalizerTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bURLStringNormalizerTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- WebPermissionPrompting (SafariLikeContracts / Contracts)
  - Targets: SafariLikeContracts
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/SiteSettings/SitePermissions.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/SiteSettings/SitePermissions.swift#L85)
  - Reference search (STRICT):
    - Patterns: `\bWebPermissionPrompting\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- WebViewPoolLeakTests (SafariLikeCoreKitTests / Tests)
  - Targets: SafariLikeCoreKitTests
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeCoreKit/Tests/SafariLikeCoreKitTests/WebViewPoolLeakTests.swift](RuntimePackages/SafariLikeCoreKit/Tests/SafariLikeCoreKitTests/WebViewPoolLeakTests.swift#L4)
  - Reference search (STRICT):
    - Patterns: `\bWebViewPoolLeakTests\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

- WebsiteDataStore (SafariLikeCoreKit / CoreKit)
  - Targets: SafariLikeCoreKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Policy/BrowserPolicy.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Policy/BrowserPolicy.swift#L84)
  - Reference search (STRICT):
    - Patterns: `\bWebsiteDataStore\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: UNUSED

## Used only in tests (0)

## Public/external surface (do NOT delete) (18)

- AccessibilityPreferenceSnapshot (SafariLikeContracts / Contracts)
  - Targets: SafariLikeContracts
  - Visibility: public
  - Definition(s):
    - [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Commands/AccessibilityPreferenceSnapshot.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Commands/AccessibilityPreferenceSnapshot.swift#L7)
  - Reference search (STRICT):
    - Patterns: `\bAccessibilityPreferenceSnapshot\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: PUBLIC-API/EXTERNAL

- BottomSheetView (SafariLikeUXKit / UXKit)
  - Targets: SafariLikeUXKit
  - Visibility: public
  - Definition(s):
    - [RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/Overview/BottomSheetView.swift](RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/Overview/BottomSheetView.swift#L6)
  - Reference search (STRICT):
    - Patterns: `\bBottomSheetView\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: PUBLIC-API/EXTERNAL

- BrowserSplitContainer (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: public
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Views/Layout/BrowserSplitContainer.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Views/Layout/BrowserSplitContainer.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bBrowserSplitContainer\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: PUBLIC-API/EXTERNAL

- CrossSceneIntent (SafariLikeContracts / Contracts)
  - Targets: SafariLikeContracts
  - Visibility: public
  - Definition(s):
    - [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Scenes/SceneContracts.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Scenes/SceneContracts.swift#L46)
  - Reference search (STRICT):
    - Patterns: `\bCrossSceneIntent\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: PUBLIC-API/EXTERNAL

- DownloadDestinationPolicy (BrowserCore / BrowserCore)
  - Targets: BrowserCore
  - Visibility: public
  - Definition(s):
    - [RuntimePackages/BrowserCore/Sources/BrowserCore/Downloads/DownloadDestinationPolicy.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Downloads/DownloadDestinationPolicy.swift#L7)
  - Reference search (STRICT):
    - Patterns: `\bDownloadDestinationPolicy\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: PUBLIC-API/EXTERNAL

- LibraryService (BrowserCore / BrowserCore)
  - Targets: BrowserCore
  - Visibility: public
  - Definition(s):
    - [RuntimePackages/BrowserCore/Sources/BrowserCore/Library/LibraryService.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Library/LibraryService.swift#L5)
  - Reference search (STRICT):
    - Patterns: `\bLibraryService\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: PUBLIC-API/EXTERNAL

- MemoryPressureNotifying (SafariLikeCoreKit / CoreKit)
  - Targets: SafariLikeCoreKit
  - Visibility: public
  - Definition(s):
    - [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Protocols/MemoryPressureNotifying.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Protocols/MemoryPressureNotifying.swift#L6)
  - Reference search (STRICT):
    - Patterns: `\bMemoryPressureNotifying\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: PUBLIC-API/EXTERNAL

- RotationTransitionObserverView (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: public
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Scene/RotationTransitionObserverView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Scene/RotationTransitionObserverView.swift#L7)
  - Reference search (STRICT):
    - Patterns: `\bRotationTransitionObserverView\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: PUBLIC-API/EXTERNAL

- SandboxedPolicyProvider (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: public
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Plugins/Boundary/PluginSandbox.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Plugins/Boundary/PluginSandbox.swift#L17)
  - Reference search (STRICT):
    - Patterns: `\bSandboxedPolicyProvider\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: PUBLIC-API/EXTERNAL

- ScriptExecutionRecord (SafariLikeContracts / Contracts)
  - Targets: SafariLikeContracts
  - Visibility: public
  - Definition(s):
    - [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/UserScripts/UserScriptModels.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/UserScripts/UserScriptModels.swift#L157)
  - Reference search (STRICT):
    - Patterns: `\bScriptExecutionRecord\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: PUBLIC-API/EXTERNAL

- SessionRestorer (BrowserCore / BrowserCore)
  - Targets: BrowserCore
  - Visibility: public
  - Definition(s):
    - [RuntimePackages/BrowserCore/Sources/BrowserCore/Session/Journal/SessionRestorer.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Session/Journal/SessionRestorer.swift#L18)
  - Reference search (STRICT):
    - Patterns: `\bSessionRestorer\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: PUBLIC-API/EXTERNAL

- SettingsDeepLink (SafariLikeContracts / Contracts)
  - Targets: SafariLikeContracts
  - Visibility: public
  - Definition(s):
    - [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Autofill/AutofillModels.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Autofill/AutofillModels.swift#L61)
  - Reference search (STRICT):
    - Patterns: `\bSettingsDeepLink\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: PUBLIC-API/EXTERNAL

- SharePayload (SafariLikeContracts / Contracts)
  - Targets: SafariLikeContracts
  - Visibility: public
  - Definition(s):
    - [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Downloads/DownloadsModels.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Downloads/DownloadsModels.swift#L140)
  - Reference search (STRICT):
    - Patterns: `\bSharePayload\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: PUBLIC-API/EXTERNAL

- SnapshotProviding (SafariLikeCoreKit / CoreKit)
  - Targets: SafariLikeCoreKit
  - Visibility: public
  - Definition(s):
    - [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Protocols/SnapshotProviding.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Protocols/SnapshotProviding.swift#L5)
  - Reference search (STRICT):
    - Patterns: `\bSnapshotProviding\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: PUBLIC-API/EXTERNAL

- TabEffect (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: public
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/StateMachine/TabEffects.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/StateMachine/TabEffects.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bTabEffect\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: PUBLIC-API/EXTERNAL

- TabReducer (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: public
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/StateMachine/TabReducer.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/StateMachine/TabReducer.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bTabReducer\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: PUBLIC-API/EXTERNAL

- UserInfoKey (SafariLikeCoreKit / CoreKit)
  - Targets: SafariLikeCoreKit
  - Visibility: public
  - Definition(s):
    - [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Diagnostics/WebViewLifecycleDebugNotifications.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Diagnostics/WebViewLifecycleDebugNotifications.swift#L11)
  - Reference search (STRICT):
    - Patterns: `\bUserInfoKey\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: PUBLIC-API/EXTERNAL

- WindowReducer (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: public
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/StateMachine/WindowReducer.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/StateMachine/WindowReducer.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bWindowReducer\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - Classification: PUBLIC-API/EXTERNAL

## Reflective/selector/stringly risks (1)

- CompanionPane (SafariLikeKit / SafariLikeKit)
  - Targets: SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/CompanionPane.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/CompanionPane.swift#L3)
  - Reference search (STRICT):
    - Patterns: `\bCompanionPane\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - String-literal hits (risk):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/Controllers/TabAttachmentController.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/Controllers/TabAttachmentController.swift#L127): activateCompanionPane
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/Controllers/TabAttachmentController.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/Controllers/TabAttachmentController.swift#L140): activateCompanionPane
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/Controllers/TabAttachmentController.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/Controllers/TabAttachmentController.swift#L146): activateCompanionPane
  - Risk notes: type name appears in string literals
  - Classification: REFLECTIVE/STRINGLY-RISK

## Tooling-limited / ambiguous (1)

Items here could not be proven UNUSED under the absolute rules (e.g. duplicate symbol names across modules).

- BrowserSession (UNVERIFIED / BrowserCore, SafariLikeKit)
  - Targets: BrowserCore,SafariLikeKit
  - Visibility: internal
  - Definition(s):
    - [RuntimePackages/BrowserCore/Sources/BrowserCore/Models/BrowserSession.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Models/BrowserSession.swift#L2)
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Session/BrowserSession.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Session/BrowserSession.swift#L29)
  - Reference search (STRICT):
    - Patterns: `\bBrowserSession\b` (code-only; excludes comments/strings; excludes definition+extension contexts)
    - Production references: 0 (no code references found)
    - Test references: 0
  - String-literal hits (risk):
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Session/BrowserSceneSession+Restore.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Session/BrowserSceneSession+Restore.swift#L11): BrowserSessionStore
  - Risk notes: duplicate definitions across modules/categories
  - Classification: TOOLING-LIMITED

