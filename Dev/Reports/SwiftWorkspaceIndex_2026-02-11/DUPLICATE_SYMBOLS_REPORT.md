# Duplicate Symbols / Shadowing Report

This reports identical top-level type names defined in multiple files/modules.
Without USR-level indexing, actual binding at each use site is TOOLING-LIMITED.

## Actions (definitions: 2; categories: SafariLikeKit)

- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Domain/SplitBrowserViewModel.Actions.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Domain/SplitBrowserViewModel.Actions.swift#L6) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/TabManager.Actions.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/TabManager.Actions.swift#L4) (SafariLikeKit)

## ActivePane (definitions: 3; categories: BrowserCore, SafariLikeKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Performance/RenderBudgetPolicy.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Performance/RenderBudgetPolicy.swift#L11) (BrowserCore)
- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Session/BrowserSessionStore.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Session/BrowserSessionStore.swift#L10) (BrowserCore)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/TabManager.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/TabManager.swift#L867) (SafariLikeKit)

## AdBlockerPlugin (definitions: 2; categories: SafariLikeKit, UNVERIFIED)

- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeBuiltinPlugins/AdBlockerPlugin.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeBuiltinPlugins/AdBlockerPlugin.swift#L15) (SafariLikeBuiltinPlugins)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Plugins/Builtins/AdBlockerPlugin.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Plugins/Builtins/AdBlockerPlugin.swift#L4) (SafariLikeKit)

## AnalyticsEvent (definitions: 2; categories: SafariLikeKit, UNVERIFIED)

- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeBuiltinPlugins/AnalyticsPlugin.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeBuiltinPlugins/AnalyticsPlugin.swift#L27) (SafariLikeBuiltinPlugins)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Plugins/Builtins/AnalyticsPlugin.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Plugins/Builtins/AnalyticsPlugin.swift#L25) (SafariLikeKit)

## AnalyticsPlugin (definitions: 2; categories: SafariLikeKit, UNVERIFIED)

- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeBuiltinPlugins/AnalyticsPlugin.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeBuiltinPlugins/AnalyticsPlugin.swift#L11) (SafariLikeBuiltinPlugins)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Plugins/Builtins/AnalyticsPlugin.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Plugins/Builtins/AnalyticsPlugin.swift#L4) (SafariLikeKit)

## Bind (definitions: 2; categories: BrowserCore, SafariLikeKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Library/SQLiteLibraryRepository.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Library/SQLiteLibraryRepository.swift#L622) (BrowserCore)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Library/SQLiteLibraryRepository.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Library/SQLiteLibraryRepository.swift#L471) (SafariLikeKit)

## BrowserSession (definitions: 2; categories: BrowserCore, SafariLikeKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Models/BrowserSession.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Models/BrowserSession.swift#L2) (BrowserCore)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Session/BrowserSession.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Session/BrowserSession.swift#L29) (SafariLikeKit)

## CaretBlinkPolicy (definitions: 2; categories: SafariLikeKit, UXKit)

- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Components/SelectableTextField.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Components/SelectableTextField.swift#L7) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/AddressBar/MicroInteractionConfig.swift](RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/AddressBar/MicroInteractionConfig.swift#L7) (SafariLikeUXKit)

## ChromeEvent (definitions: 3; categories: Contracts, SafariLikeKit, UNVERIFIED)

- def: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Chrome/ChromeViewContracts.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Chrome/ChromeViewContracts.swift#L6) (SafariLikeContracts)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Chrome/ChromeTypes.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Chrome/ChromeTypes.swift#L11) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeUXKit/Chrome/ChromeStateMachine.swift](RuntimePackages/SafariLikeUXKit/Chrome/ChromeStateMachine.swift#L5) (UNVERIFIED)

## ChromeEventRouter (definitions: 2; categories: SafariLikeKit, UNVERIFIED)

- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/ChromeEventRouter.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/ChromeEventRouter.swift#L2) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeUXKit/Chrome/ChromeStateMachine.swift](RuntimePackages/SafariLikeUXKit/Chrome/ChromeStateMachine.swift#L32) (UNVERIFIED)

## ChromeViewState (definitions: 3; categories: Contracts, SafariLikeKit, UNVERIFIED)

- def: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Chrome/ChromeViewContracts.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Chrome/ChromeViewContracts.swift#L15) (SafariLikeContracts)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Chrome/ChromeTypes.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Chrome/ChromeTypes.swift#L2) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeUXKit/Chrome/ChromeStateMachine.swift](RuntimePackages/SafariLikeUXKit/Chrome/ChromeStateMachine.swift#L16) (UNVERIFIED)

## CodingKeys (definitions: 8; categories: BrowserCore, Contracts, SafariLikeKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Session/BrowserSessionStore.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Session/BrowserSessionStore.swift#L86) (BrowserCore)
- def: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Journal/JournalEvent.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Journal/JournalEvent.swift#L233) (SafariLikeContracts)
- def: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Journal/JournalEvent.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Journal/JournalEvent.swift#L356) (SafariLikeContracts)
- def: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Navigation/TabNavigationState.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Navigation/TabNavigationState.swift#L27) (SafariLikeContracts)
- def: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Scenes/SceneContracts.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Scenes/SceneContracts.swift#L48) (SafariLikeContracts)
- def: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/WebsitePreferences/WebsitePreferences.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/WebsitePreferences/WebsitePreferences.swift#L118) (SafariLikeContracts)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/StateMachine/TabState.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/StateMachine/TabState.swift#L67) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/StateMachine/WindowState.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/StateMachine/WindowState.swift#L39) (SafariLikeKit)

## CompanionSection (definitions: 2; categories: SafariLikeKit)

- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/BrowserUIStateImpl.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/BrowserUIStateImpl.swift#L17) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/ViewModel/SplitBrowserViewModel.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/ViewModel/SplitBrowserViewModel.swift#L11) (SafariLikeKit)

## Configuration (definitions: 10; categories: BrowserCore, SafariLikeKit, UXKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Library/HistoryEngine.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Library/HistoryEngine.swift#L5) (BrowserCore)
- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Library/LibraryService.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Library/LibraryService.swift#L6) (BrowserCore)
- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Library/SQLiteLibraryRepository.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Library/SQLiteLibraryRepository.swift#L18) (BrowserCore)
- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Library/SuggestionsEngine.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Library/SuggestionsEngine.swift#L15) (BrowserCore)
- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Library/TopSitesEngine.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Library/TopSitesEngine.swift#L5) (BrowserCore)
- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Telemetry/TelemetryEngine.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Telemetry/TelemetryEngine.swift#L10) (BrowserCore)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Library/SQLiteLibraryRepository.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Library/SQLiteLibraryRepository.swift#L7) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Metrics/MetricsCollector.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Metrics/MetricsCollector.swift#L8) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/OverviewPhysicsEngine.swift](RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/OverviewPhysicsEngine.swift#L100) (SafariLikeUXKit)
- def: [RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/StateMachines/ChromeStateMachine.swift](RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/StateMachines/ChromeStateMachine.swift#L32) (SafariLikeUXKit)

## Coordinator (definitions: 5; categories: SafariLikeKit)

- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Platform/Web/WebViewCoordinator.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Platform/Web/WebViewCoordinator.swift#L427) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Components/SelectableTextField.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Components/SelectableTextField.swift#L113) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Debug/TouchInspectorDebugModifier.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Debug/TouchInspectorDebugModifier.swift#L48) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Renderer/StartPageRenderer.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Renderer/StartPageRenderer.swift#L264) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Views/Overlays/QuickLookPreview.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Views/Overlays/QuickLookPreview.swift#L18) (SafariLikeKit)

## DarkModePlugin (definitions: 2; categories: SafariLikeKit, UNVERIFIED)

- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeBuiltinPlugins/DarkModePlugin.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeBuiltinPlugins/DarkModePlugin.swift#L9) (SafariLikeBuiltinPlugins)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Plugins/Builtins/DarkModePlugin.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Plugins/Builtins/DarkModePlugin.swift#L4) (SafariLikeKit)

## DebugMetrics (definitions: 2; categories: CoreKit, SafariLikeKit)

- def: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift#L128) (SafariLikeCoreKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Snapshots/SnapshotService.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Snapshots/SnapshotService.swift#L82) (SafariLikeKit)

## Decision (definitions: 6; categories: BrowserCore, SafariLikeKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Performance/RenderBudgetPolicy.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Performance/RenderBudgetPolicy.swift#L45) (BrowserCore)
- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Performance/TabResourcePolicy.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Performance/TabResourcePolicy.swift#L80) (BrowserCore)
- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Policy/TabDiscardPolicy.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Policy/TabDiscardPolicy.swift#L55) (BrowserCore)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Policy/RenderVisibilityPolicy.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Policy/RenderVisibilityPolicy.swift#L28) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Policy/WebContentVisibilityPolicy.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Policy/WebContentVisibilityPolicy.swift#L17) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Policy/WebViewRequirementPolicy.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Policy/WebViewRequirementPolicy.swift#L10) (SafariLikeKit)

## DetentsIfAvailable (definitions: 2; categories: SafariLikeKit)

- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Companion/CompanionListView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Companion/CompanionListView.swift#L144) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Views/Overlays/DownloadsPopoverView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Views/Overlays/DownloadsPopoverView.swift#L93) (SafariLikeKit)

## DeviceLayout (definitions: 2; categories: UXKit)

- def: [RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/Layout/DeviceLayout.swift](RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/Layout/DeviceLayout.swift#L5) (SafariLikeUXKit)
- def: [RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/Layout/DeviceLayout.swift](RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/Layout/DeviceLayout.swift#L27) (SafariLikeUXKit)

## Entry (definitions: 2; categories: BrowserCore, SafariLikeKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Session/Restore/ReplayDiagnostics.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Session/Restore/ReplayDiagnostics.swift#L4) (BrowserCore)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Session/BrowserSceneSessionRegistry.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Session/BrowserSceneSessionRegistry.swift#L11) (SafariLikeKit)

## Event (definitions: 4; categories: CoreKit, SafariLikeKit, UXKit)

- def: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/Lifecycle/TabPageLifecycleStateMachine.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/Lifecycle/TabPageLifecycleStateMachine.swift#L49) (SafariLikeCoreKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Metrics/Tracing/PerformanceTracer.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Metrics/Tracing/PerformanceTracer.swift#L50) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/AddressBar/AddressBarEntryStateMachine.swift](RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/AddressBar/AddressBarEntryStateMachine.swift#L27) (SafariLikeUXKit)
- def: [RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/StateMachines/ChromeStateMachine.swift](RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/StateMachines/ChromeStateMachine.swift#L16) (SafariLikeUXKit)

## InMemoryWebsitePreferencesStore (definitions: 2; categories: Tests)

- def: [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/FormFillPolicyEngineTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/FormFillPolicyEngineTests.swift#L6) (BrowserCoreTests)
- def: [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/PrivacyReportEngineTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/PrivacyReportEngineTests.swift#L6) (BrowserCoreTests)

## Input (definitions: 9; categories: BrowserCore, SafariLikeKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Performance/RenderBudgetPolicy.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Performance/RenderBudgetPolicy.swift#L16) (BrowserCore)
- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Performance/TabResourcePolicy.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Performance/TabResourcePolicy.swift#L44) (BrowserCore)
- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Policy/TabDiscardPolicy.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Policy/TabDiscardPolicy.swift#L43) (BrowserCore)
- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Policy/TabResourceScore.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Policy/TabResourceScore.swift#L5) (BrowserCore)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Discard/DiscardController.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Discard/DiscardController.swift#L122) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Policy/RenderVisibilityPolicy.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Policy/RenderVisibilityPolicy.swift#L14) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/RelatedPolicy.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/RelatedPolicy.swift#L7) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/Spine/BrowserLayoutSpine.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/Spine/BrowserLayoutSpine.swift#L7) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/State/BrowserUXState.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/State/BrowserUXState.swift#L38) (SafariLikeKit)

## Item (definitions: 2; categories: BrowserCore, SafariLikeKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Session/SessionState.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Session/SessionState.swift#L89) (BrowserCore)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Sidebar/SidebarView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Sidebar/SidebarView.swift#L5) (SafariLikeKit)

## Key (definitions: 3; categories: CoreKit, SafariLikeKit)

- def: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Context/WebContextManager.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Context/WebContextManager.swift#L6) (SafariLikeCoreKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Lifecycle/WatchdogController.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Lifecycle/WatchdogController.swift#L8) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/Components/TabTaskRegistry.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/Components/TabTaskRegistry.swift#L5) (SafariLikeKit)

## Kind (definitions: 7; categories: Contracts, CoreKit, SafariLikeKit)

- def: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Autofill/AutofillModels.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Autofill/AutofillModels.swift#L62) (SafariLikeContracts)
- def: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Journal/JournalEvent.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Journal/JournalEvent.swift#L243) (SafariLikeContracts)
- def: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Scenes/SceneContracts.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Scenes/SceneContracts.swift#L54) (SafariLikeContracts)
- def: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/Navigation/URLStringNormalizer.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/Navigation/URLStringNormalizer.swift#L11) (SafariLikeCoreKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Lifecycle/WatchdogController.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Lifecycle/WatchdogController.swift#L12) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Metrics/MetricsEvent.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Metrics/MetricsEvent.swift#L5) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/ViewModel/SplitBrowserViewModel.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/ViewModel/SplitBrowserViewModel.swift#L145) (SafariLikeKit)

## LeakSentinel (definitions: 2; categories: Tests)

- def: [RuntimePackages/SafariLikeCoreKit/Tests/SafariLikeCoreKitTests/TestSupport/LeakSentinel.swift](RuntimePackages/SafariLikeCoreKit/Tests/SafariLikeCoreKitTests/TestSupport/LeakSentinel.swift#L9) (SafariLikeCoreKitTests)
- def: [RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/TestSupport/LeakSentinel.swift](RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/TestSupport/LeakSentinel.swift#L2) (SafariLikeKitTests)

## LibraryRepository (definitions: 2; categories: BrowserCore, SafariLikeKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Library/LibraryRepository.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Library/LibraryRepository.swift#L9) (BrowserCore)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Library/LibraryRepository.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Library/LibraryRepository.swift#L3) (SafariLikeKit)

## LibraryRepositoryError (definitions: 2; categories: BrowserCore, SafariLikeKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Library/LibraryRepository.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Library/LibraryRepository.swift#L3) (BrowserCore)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Library/LibraryRepository.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Library/LibraryRepository.swift#L27) (SafariLikeKit)

## MemoryPressureEvent (definitions: 3; categories: CoreKit, SafariLikeKit)

- def: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Engine/EngineController.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Engine/EngineController.swift#L87) (SafariLikeCoreKit)
- def: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Protocols/MemoryPressureNotifying.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Protocols/MemoryPressureNotifying.swift#L14) (SafariLikeCoreKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Metrics/BrowserMetrics.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Metrics/BrowserMetrics.swift#L48) (SafariLikeKit)

## MemoryPressureLevel (definitions: 4; categories: BrowserCore, Contracts, CoreKit, SafariLikeKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Performance/TabResourcePolicy.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Performance/TabResourcePolicy.swift#L8) (BrowserCore)
- def: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Reliability/CrashContextSnapshot.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Reliability/CrashContextSnapshot.swift#L2) (SafariLikeContracts)
- def: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Engine/EngineController.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Engine/EngineController.swift#L56) (SafariLikeCoreKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Metrics/MetricsEvent.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Metrics/MetricsEvent.swift#L19) (SafariLikeKit)

## Metrics (definitions: 3; categories: BrowserCore, SafariLikeKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Models/HeuristicsEngine.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Models/HeuristicsEngine.swift#L207) (BrowserCore)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/BrowserConstants.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/BrowserConstants.swift#L19) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Discard/DiscardController.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Discard/DiscardController.swift#L8) (SafariLikeKit)

## Mode (definitions: 4; categories: BrowserCore, Contracts, UXKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Session/Restore/ReplayErrorPolicy.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Session/Restore/ReplayErrorPolicy.swift#L12) (BrowserCore)
- def: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/AddressBar/AddressBarViewContracts.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/AddressBar/AddressBarViewContracts.swift#L37) (SafariLikeContracts)
- def: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Privacy/WebsiteDataPolicy.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Privacy/WebsiteDataPolicy.swift#L10) (SafariLikeContracts)
- def: [RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/AddressBar/AddressBarEntryStateMachine.swift](RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/AddressBar/AddressBarEntryStateMachine.swift#L10) (SafariLikeUXKit)

## NavigationPolicy (definitions: 2; categories: CoreKit, SafariLikeKit)

- def: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Policy/SafariNavigationPolicyLayer.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Policy/SafariNavigationPolicyLayer.swift#L7) (SafariLikeCoreKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Policy/CorePolicies/NavigationPolicy.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Policy/CorePolicies/NavigationPolicy.swift#L3) (SafariLikeKit)

## Options (definitions: 4; categories: BrowserCore, SafariLikeKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Downloads/DownloadCenter.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Downloads/DownloadCenter.swift#L14) (BrowserCore)
- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Downloads/DownloadDestinationPolicy.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Downloads/DownloadDestinationPolicy.swift#L8) (BrowserCore)
- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Session/SceneSessionStore.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Session/SceneSessionStore.swift#L27) (BrowserCore)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/AppGlue/DefaultDownloadFileIO.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/AppGlue/DefaultDownloadFileIO.swift#L11) (SafariLikeKit)

## Output (definitions: 2; categories: BrowserCore, SafariLikeKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Session/Restore/SessionReplayEngine.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Session/Restore/SessionReplayEngine.swift#L5) (BrowserCore)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/Spine/ChromeMetricsBuilder.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/Spine/ChromeMetricsBuilder.swift#L7) (SafariLikeKit)

## PageView (definitions: 2; categories: SafariLikeKit, UNVERIFIED)

- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeBuiltinPlugins/AnalyticsPlugin.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeBuiltinPlugins/AnalyticsPlugin.swift#L20) (SafariLikeBuiltinPlugins)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Plugins/Builtins/AnalyticsPlugin.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Plugins/Builtins/AnalyticsPlugin.swift#L17) (SafariLikeKit)

## PaneState (definitions: 2; categories: BrowserCore, SafariLikeKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Session/SessionState.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Session/SessionState.swift#L41) (BrowserCore)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/SplitPane/SplitPaneTypes.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/SplitPane/SplitPaneTypes.swift#L9) (SafariLikeKit)

## PersistedState (definitions: 2; categories: BrowserCore, Tests)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Downloads/DownloadCenter.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Downloads/DownloadCenter.swift#L335) (BrowserCore)
- def: [RuntimePackages/BrowserCore/Tests/BrowserCoreTests/DownloadCenterTests.swift](RuntimePackages/BrowserCore/Tests/BrowserCoreTests/DownloadCenterTests.swift#L6) (BrowserCoreTests)

## Persistence (definitions: 2; categories: BrowserCore, Contracts)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Telemetry/TelemetryEngine.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Telemetry/TelemetryEngine.swift#L19) (BrowserCore)
- def: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Privacy/WebsiteDataPolicy.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Privacy/WebsiteDataPolicy.swift#L14) (SafariLikeContracts)

## RelatedContainerView (definitions: 2; categories: SafariLikeKit)

- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Related/RelatedContainerView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Related/RelatedContainerView.swift#L9) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Related/RelatedContainerView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Related/RelatedContainerView.swift#L103) (SafariLikeKit)

## SceneFactory (definitions: 2; categories: Tests)

- def: [RuntimePackages/SafariLikeCoreKit/Tests/SafariLikeCoreKitTests/TestSupport/SceneFactory.swift](RuntimePackages/SafariLikeCoreKit/Tests/SafariLikeCoreKitTests/TestSupport/SceneFactory.swift#L4) (SafariLikeCoreKitTests)
- def: [RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/TestSupport/SceneFactory.swift](RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/TestSupport/SceneFactory.swift#L5) (SafariLikeKitTests)

## SceneRuntimeContext (definitions: 2; categories: CoreKit, SafariLikeKit)

- def: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/SceneRuntimeContext.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/SceneRuntimeContext.swift#L9) (SafariLikeCoreKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Lifecycle/SceneRuntimeContext.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Lifecycle/SceneRuntimeContext.swift#L8) (SafariLikeKit)

## SearchEngine (definitions: 2; categories: App, Contracts)

- def: [App/AppSettings.swift](App/AppSettings.swift#L25) (webOS)
- def: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/DefaultURLs.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/DefaultURLs.swift#L18) (SafariLikeContracts)

## SidebarOverlay (definitions: 2; categories: SafariLikeKit)

- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Sidebar/SidebarOverlay.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Sidebar/SidebarOverlay.swift#L4) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/State/BrowserUXState.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/State/BrowserUXState.swift#L116) (SafariLikeKit)

## Snapshot (definitions: 5; categories: CoreKit, SafariLikeKit, UXKit)

- def: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Diagnostics/CoreKitMetrics.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Diagnostics/CoreKitMetrics.swift#L8) (SafariLikeCoreKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Policy/WebContentVisibilityPolicy.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Policy/WebContentVisibilityPolicy.swift#L9) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Scene/SceneMetricsReader.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Scene/SceneMetricsReader.swift#L21) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/AddressBar/AddressBarEntryStateMachine.swift](RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/AddressBar/AddressBarEntryStateMachine.swift#L15) (SafariLikeUXKit)
- def: [RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/AddressBar/AddressBarUIStateMachine.swift](RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/AddressBar/AddressBarUIStateMachine.swift#L107) (SafariLikeUXKit)

## SplitMode (definitions: 2; categories: SafariLikeKit, UIKit)

- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/SplitPane/SplitPaneTypes.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/SplitPane/SplitPaneTypes.swift#L5) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit/SplitPaneCoordinator.swift](RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit/SplitPaneCoordinator.swift#L10) (SafariLikeUIKit)

## SplitPaneCoordinator (definitions: 2; categories: SafariLikeKit, UIKit)

- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/SplitPane/SplitPaneCoordinator.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/SplitPane/SplitPaneCoordinator.swift#L5) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit/SplitPaneCoordinator.swift](RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit/SplitPaneCoordinator.swift#L8) (SafariLikeUIKit)

## SplitViewState (definitions: 2; categories: BrowserCore, SafariLikeKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Session/BrowserSessionStore.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Session/BrowserSessionStore.swift#L14) (BrowserCore)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/TabManagerState.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/TabManagerState.swift#L19) (SafariLikeKit)

## Spring (definitions: 2; categories: UXKit)

- def: [RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/Physics/SafariPhysicsConfig.swift](RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/Physics/SafariPhysicsConfig.swift#L10) (SafariLikeUXKit)
- def: [RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/Policy/UXPolicy.swift](RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/Policy/UXPolicy.swift#L60) (SafariLikeUXKit)

## SQLiteLibraryRepository (definitions: 2; categories: BrowserCore, SafariLikeKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Library/SQLiteLibraryRepository.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Library/SQLiteLibraryRepository.swift#L17) (BrowserCore)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Library/SQLiteLibraryRepository.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Library/SQLiteLibraryRepository.swift#L6) (SafariLikeKit)

## StartPageClosureActionHandler (definitions: 2; categories: SafariLikeKit)

- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Renderer/StartPageRenderer.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Renderer/StartPageRenderer.swift#L272) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/StartPage/StartPageView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/StartPage/StartPageView.swift#L112) (SafariLikeKit)

## State (definitions: 12; categories: BrowserCore, CoreKit, SafariLikeKit, UXKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Models/BrowserTab.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Models/BrowserTab.swift#L10) (BrowserCore)
- def: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Diagnostics/CoreKitMetrics.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Diagnostics/CoreKitMetrics.swift#L39) (SafariLikeCoreKit)
- def: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Restore/UXRestoreController.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Restore/UXRestoreController.swift#L9) (SafariLikeCoreKit)
- def: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/Lifecycle/TabPageLifecycleStateMachine.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/Lifecycle/TabPageLifecycleStateMachine.swift#L16) (SafariLikeCoreKit)
- def: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift#L152) (SafariLikeCoreKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Library/InMemoryLibraryRepository.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Library/InMemoryLibraryRepository.swift#L4) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Domain/SplitBrowserViewModel.State.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Domain/SplitBrowserViewModel.State.swift#L31) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/TabManager.State.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/TabManager.State.swift#L4) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Platform/Web/WebViewCoordinator.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Platform/Web/WebViewCoordinator.swift#L113) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Lifecycle/AppLifecycleCoordinator.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Lifecycle/AppLifecycleCoordinator.swift#L7) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/OverviewPhysicsEngine.swift](RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/OverviewPhysicsEngine.swift#L93) (SafariLikeUXKit)
- def: [RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/StateMachines/ChromeStateMachine.swift](RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/StateMachines/ChromeStateMachine.swift#L9) (SafariLikeUXKit)

## Submission (definitions: 2; categories: CoreKit, UXKit)

- def: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/AddressBar/AddressBarReducer.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/AddressBar/AddressBarReducer.swift#L6) (SafariLikeCoreKit)
- def: [RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/AddressBar/AddressBarFeature.swift](RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/AddressBar/AddressBarFeature.swift#L102) (SafariLikeUXKit)

## TabDescriptor (definitions: 2; categories: BrowserCore)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Performance/TabResourcePolicy.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Performance/TabResourcePolicy.swift#L19) (BrowserCore)
- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Policy/TabDiscardPolicy.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Policy/TabDiscardPolicy.swift#L9) (BrowserCore)

## TabDiscardPolicy (definitions: 2; categories: BrowserCore, SafariLikeKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Policy/TabDiscardPolicy.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Policy/TabDiscardPolicy.swift#L8) (BrowserCore)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Discard/TabDiscardPolicy.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Discard/TabDiscardPolicy.swift#L21) (SafariLikeKit)

## TabGroupColor (definitions: 2; categories: BrowserCore, CoreKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Models/BrowserTabGroup.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Models/BrowserTabGroup.swift#L27) (BrowserCore)
- def: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Models/TabGroupColor.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Models/TabGroupColor.swift#L8) (SafariLikeCoreKit)

## TabManager (definitions: 2; categories: App, SafariLikeKit)

- def: [App/AppBrowserSessionController.swift](App/AppBrowserSessionController.swift#L299) (webOS)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/TabManager.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/TabManager.swift#L9) (SafariLikeKit)

## TabRegistry (definitions: 2; categories: CoreKit)

- def: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Policy/BrowserPolicy.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Policy/BrowserPolicy.swift#L31) (SafariLikeCoreKit)
- def: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/Tab/TabRegistry.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/Tab/TabRegistry.swift#L4) (SafariLikeCoreKit)

## TabState (definitions: 4; categories: BrowserCore, CoreKit, SafariLikeKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Reader/ReaderModeEngine.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Reader/ReaderModeEngine.swift#L10) (BrowserCore)
- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Session/SessionState.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Session/SessionState.swift#L51) (BrowserCore)
- def: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Public/TabState.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Public/TabState.swift#L19) (SafariLikeCoreKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/StateMachine/TabState.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/StateMachine/TabState.swift#L13) (SafariLikeKit)

## Timing (definitions: 2; categories: Contracts, CoreKit)

- def: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Plugins/PluginManifest.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Plugins/PluginManifest.swift#L9) (SafariLikeContracts)
- def: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/Timing/TimingPolicy.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/Timing/TimingPolicy.swift#L17) (SafariLikeCoreKit)

## UIKitMemoryPressureSource (definitions: 2; categories: SafariLikeKit, UIKit)

- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Memory/UIKitMemoryPressureSource.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Memory/UIKitMemoryPressureSource.swift#L7) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit/Composition/UIKitMemoryPressureSource.swift](RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit/Composition/UIKitMemoryPressureSource.swift#L9) (SafariLikeUIKit)

## URLStringNormalizer (definitions: 2; categories: BrowserCore, CoreKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Library/URLStringNormalizer.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Library/URLStringNormalizer.swift#L5) (BrowserCore)
- def: [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/Navigation/URLStringNormalizer.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/Navigation/URLStringNormalizer.swift#L10) (SafariLikeCoreKit)

## UserAgentMode (definitions: 2; categories: Contracts, SafariLikeKit)

- def: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/WebsitePreferences/WebsitePreferences.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/WebsitePreferences/WebsitePreferences.swift#L45) (SafariLikeContracts)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Plugins/Core/BrowserSettingsSnapshot.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Plugins/Core/BrowserSettingsSnapshot.swift#L9) (SafariLikeKit)

## UserScript (definitions: 2; categories: Contracts)

- def: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Plugins/PluginManifest.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Plugins/PluginManifest.swift#L8) (SafariLikeContracts)
- def: [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/UserScripts/UserScriptModels.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/UserScripts/UserScriptModels.swift#L64) (SafariLikeContracts)

## Viewport (definitions: 2; categories: SafariLikeKit)

- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/BrowserContentViewportContract.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/BrowserContentViewportContract.swift#L14) (SafariLikeKit)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/State/BrowserUXState.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/State/BrowserUXState.swift#L11) (SafariLikeKit)

## WeakBox (definitions: 2; categories: Tests)

- def: [RuntimePackages/SafariLikeCoreKit/Tests/SafariLikeCoreKitTests/TestSupport/LeakSentinel.swift](RuntimePackages/SafariLikeCoreKit/Tests/SafariLikeCoreKitTests/TestSupport/LeakSentinel.swift#L11) (SafariLikeCoreKitTests)
- def: [RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/TestSupport/LeakSentinel.swift](RuntimePackages/SafariLikeKit/Tests/SafariLikeKitTests/TestSupport/LeakSentinel.swift#L5) (SafariLikeKitTests)

## WindowState (definitions: 2; categories: BrowserCore, SafariLikeKit)

- def: [RuntimePackages/BrowserCore/Sources/BrowserCore/Session/SessionState.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Session/SessionState.swift#L23) (BrowserCore)
- def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/StateMachine/WindowState.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Engine/StateMachine/WindowState.swift#L3) (SafariLikeKit)

