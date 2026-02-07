# Phase 04 — UI/UX Policy Alignment (Safari-like)

Date: 2026-02-02

## Goals

- Make UI behavior feel Safari-like.
- Eliminate duplicated layout / gesture work.
- Enforce “read policy from one place” (no view-level hardcoding of thresholds/timings/z-order).

## Central Policies

### 1) `UXPolicy` (SafariLikeUXKit)

Single source of truth for Safari-like tuning knobs.

- Address bar policy: `UXPolicy.addressBar.*`
- Chrome collapse policy: `UXPolicy.chromeCollapse.*`
- Edge swipe navigation: `UXPolicy.swipeNavigation.*`
- Tab overview policy:
  - Layout policy: `UXPolicy.tabOverview.layout`
  - Physics policy: `UXPolicy.tabOverview.physics`
  - Thumbnail cooldown: `UXPolicy.tabOverview.thumbnailCaptureCooldownSeconds`
- Split view policy: `UXPolicy.splitBrowser.*`
- Gesture priority/tuning:
  - `UXPolicy.gestures.isTabOverviewFromChromeEnabled`
  - `UXPolicy.gestures.tabOverviewFromChromeMinimumDistance`
  - `UXPolicy.gestures.tabOverviewInteractionMinimumDistance`
  - `UXPolicy.gestures.tabOverviewCardMinimumDistance`

### 2) `LayoutPolicy` (SafariLikeUXKit)

Central source of truth for z-order / layering.

- Z-order constants: `UXPolicy.layout.zOrder.*`
  - `webContent`, `startPage`
  - `relatedSidebar`, `relatedOverlay`
  - `chrome`, `companion`
  - `tabOverview`, `omniboxOverlay`

## Fixes Applied (What was “off” and how it was corrected)

### A) Tab Overview layout hardcoded to `.default`

Problem:
- `TabOverviewView` and `SafariTabOverviewView` used `OverviewLayoutPolicy = .default` locally.
- This made overview behavior diverge from resolved per-device policy.

Fix:
- Both views now read `OverviewLayoutPolicy` from `EnvironmentValues.uxPolicy`.

Files:
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Tabs/TabOverviewView.swift
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Tabs/Components/SafariTabOverviewView.swift

### B) Snapshot / thumbnail pipeline triggered from multiple overview implementations

Problem:
- Both overview variants requested overview thumbnail capture on appear, causing duplicated triggers.

Fix:
- Centralized capture request in the shared overlay container (`TabOverviewOverlay`).
- Individual overview views no longer call `requestOverviewThumbnailsCapture()`.

Files:
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Tabs/TabOverviewOverlay.swift
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Tabs/TabOverviewView.swift
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Tabs/Components/SafariTabOverviewView.swift

### C) Gesture thresholds were hardcoded in UI

Problem:
- Chrome “drag to open overview” used a hardcoded `minimumDistance: 12`.
- Overview interaction tracking used hardcoded `minimumDistance: 1`.

Fix:
- Moved these thresholds into `UXPolicy.gestures.*` and wired UI to read from policy.

Files:
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Header/SafariHeaderView.swift
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Tabs/TabOverviewView.swift
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Tabs/Components/SafariTabOverviewView.swift
- RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/Policy/UXPolicy.swift

### D) Layout resolver used `UXPolicy.default` instead of injected policy

Problem:
- `BrowserLayoutResolver` used `UXPolicy.default.splitBrowser.splitEnabledMinWidth`.

Fix:
- `BrowserLayoutResolver.resolve(...)` now accepts `uxPolicy` and uses it for split enablement.

Files:
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/BrowserLayoutResolver.swift
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/BrowserView.swift

### E) Z-order magic numbers scattered across UI

Problem:
- Multiple `.zIndex(…)` values were hardcoded across layout surfaces.

Fix:
- Introduced `LayoutPolicy.ZOrder` and routed key layout layers to use `uxPolicy.layout.zOrder.*`.
- Made StartPage vs WebContent ordering explicit.

Files:
- RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/Policy/LayoutPolicy.swift
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/SplitBrowserRootView.swift
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/PrimaryPane.swift

## Notes / Next sweep candidates

- Some overview per-card gestures still embed minimum distances internally; if we want full strictness, wire those to `UXPolicy.gestures.tabOverviewCardMinimumDistance`.
- If any other overlays use `.zIndex(<literal>)`, migrate them to `UXPolicy.layout.zOrder` for consistency.
