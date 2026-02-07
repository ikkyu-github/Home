# Phase 2 — Composition Root & Lifecycle Control

This phase enforces a strict rule:

- SwiftUI views **may create composition roots**.
- SwiftUI views **must not create core/runtime objects** (sessions, WebKit pools, stores).

## Ownership (single source of truth)

```
Process (App)
└── AppCompositionRoot (1x)
    ├── AppLifecycleCoordinator (shared)
    ├── CrashGuard
    ├── SceneMetrics
    ├── AppSettings
    ├── WebsitePreferencesStore (app-scope)
    ├── DownloadManager (app-scope)
    └── AppBrowserSessionController (app-scope window/session registry)

Window / Scene (per WindowGroup instance)
└── SceneCompositionRoot (1x per SwiftUI scene)
    ├── BrowserSceneSession (1x per window)
    ├── TabThumbnailStore (1x per window)
    ├── SceneRuntimeContext (from AppLifecycleCoordinator)
    └── RelatedChromeState (UI state, 1x per window)
```

## Lifecycle flow (idempotent)

### App boot

- `SafariPadCloneApp` creates `AppCompositionRoot` once.
- App calls `await appRoot.bootstrapIfNeeded()`.
- Gate: `AppCompositionRoot.bootstrapState` prevents duplicate work.

### Scene boot

- `SceneRootView` creates `SceneCompositionRoot` once per SwiftUI scene.
- `AppRootView` derives a stable `(sceneID, windowID)` from:
  1) `UISceneSession.persistentIdentifier` (preferred)
  2) `@SceneStorage` fallback
- `AppRootView` calls `sceneRoot.configureIdentityIfNeeded(...)`.
- `AppRootView` calls `await sceneRoot.bootstrapIfNeeded(...)`.
- Gate: `SceneCompositionRoot.bootstrapState` prevents double bootstrap from repeated SwiftUI `.task` / `.onAppear`.

### Lifecycle registration

- `SafariLikeBrowserView.onAppear` calls `sceneRoot.registerLifecycleIfNeeded(...)`.
- Gate: `SceneCompositionRoot` tracks whether registration already happened.

## Dedupe points (anti-double-trigger)

- App:
  - `AppCompositionRoot.bootstrapState` + stored `bootstrapTask`
- Scene:
  - `SceneCompositionRoot.bootstrapState` + stored `bootstrapTask`
  - `SceneCompositionRoot.configureIdentityIfNeeded` (only configures once)
  - `SceneCompositionRoot.registerLifecycleIfNeeded` (only registers once)

## Files

- App wiring:
  - `App/SafariPadCloneApp.swift`
  - `App/AppRootView.swift`
  - `App/AppBrowserSessionController.swift`
  - `App/AppDelegate.swift`

- SafariLikeKit injection surface:
  - `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/SafariLikeFactory.swift`
