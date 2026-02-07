# WKWebView Layout Contract Scan

Date: 2026-02-07

This repo follows a strict SwiftUI layout + hit-testing contract for WKWebView-based surfaces:

- Do **not** place bottom chrome over the web canvas using `.overlay(alignment: .bottom)`.
- Do **not** use `.ignoresSafeArea(...)` on web/content host containers (prevents “ghost” hit-test regions and underlap).
- Reserve bottom chrome space using `.safeAreaInset(edge: .bottom)`.
- Avoid stacking bottom insets/paddings that “double count” safe-area.

## Fixes Applied

These were contract violations (web/content containers bypassing safe areas) and are now corrected:

- Landscape layout now respects safe areas and avoids manual safe-area padding:
  - RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/LandscapeBrowserLayout.swift:51
- Root web-canvas host now respects safe areas (removed `.ignoresSafeArea` from the root container):
  - RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/SplitBrowserRootView.swift:120
- Split web-canvas host now respects safe areas (removed `.ignoresSafeArea` from the split content container):
  - RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/SplitBrowserView.swift:61
- Start Page renderer/view no longer relies on full-bleed safe-area bypass for its background:
  - RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Renderer/StartPageRenderer.swift:44
  - RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/StartPage/StartPageView.swift:53
  - RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/StartPage/StartPageBackgroundView.swift:1

## Scan Results

### Bottom-chrome overlay check

- Pattern: `.overlay(alignment: .bottom)`
- Result: **no matches** (contract satisfied)

### Remaining `ignoresSafeArea(...)` occurrences

All remaining occurrences are **intentionally allowed** because they are:

- overlay-only (scrims / full-screen overlays), or
- background-only painting (does not host web content and does not affect hit-testing of the web canvas), or
- dedicated non-web UI surfaces (e.g. bottom sheet component).

Allowed occurrences (file:line → why):

- RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/Overview/BottomSheetView.swift:94
  - Bottom sheet component; not a WKWebView host.
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Restore/RestoreSnapshotLoadingView.swift:23
  - Restore overlay surface; does not host WKWebView.
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Restore/RestoreSnapshotLoadingView.swift:50
  - Restore overlay surface; does not host WKWebView.
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Restore/RestoreSnapshotLoadingView.swift:60
  - Restore overlay surface; does not host WKWebView.
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Restore/SkeletonWebPlaceholder.swift:14
  - Placeholder overlay; does not host WKWebView.
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/StartPage/StartPageSearchBar.swift:52
  - Background-only material extension for the search bar.
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Related/RelatedContainerView.swift:52
  - Scrim background only; Related is presented as an overlay.
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/BrowserView.swift:148
  - Full-bleed background painting only.
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/LandscapeBrowserLayout.swift:124
  - Full-bleed background painting only.
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Sidebar/SidebarView.swift:69
  - Sidebar surface; not a WKWebView host.
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Tabs/TabOverviewOverlay.swift:34
  - Tab overview overlay; not a WKWebView host.
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Tabs/TabOverviewOverlay.swift:39
  - Tab overview overlay; not a WKWebView host.
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Sidebar/SidebarOverlay.swift:29
  - Sidebar overlay presentation; not a WKWebView host.
