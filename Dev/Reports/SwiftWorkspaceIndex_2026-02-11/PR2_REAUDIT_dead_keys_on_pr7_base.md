# PR2 Re-Audit — Dead Keys (STRICT) on `origin/pr7-layout-contract-tests`

Date: 2026-02-11

This document re-audits “dead keys/signals” on the **current base** (`origin/pr7-layout-contract-tests`) because the earlier report at Dev/Reports/SwiftWorkspaceIndex_2026-02-11/DEAD_KEYS_REPORT.md is **not consistent with the current tree** (it flagged multiple EnvironmentValues keys as unused that are now demonstrably used).

## Scope / Method (STRICT)

- **EnvironmentValues**: only counts usages that are literal SwiftUI callsites:
  - reads: `@Environment(\.key)` (and `Environment(\.key)`)
  - writes: `.environment(\.key, ...)`
- **UserDefaults/AppStorage**: only counts **literal string** keys in code (e.g. `forKey: "..."`, `@AppStorage("...")`).
- **Notification.Name**: only counts **literal** `Notification.Name("...")` occurrences at post/observe sites.
- Anything routed through constants / static lets / computed indirection is **TOOLING-LIMITED** (not safe to delete under STRICT rules).

## EnvironmentValues — Verified Used (NOT dead)

These keys are actively used on this base:

- `keyboardHeight`
  - definition: RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Platform/Input/KeyboardHeightEnvironment.swift
  - write: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/BrowserRootView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/BrowserRootView.swift#L51)
  - read: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/BrowserView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/BrowserView.swift#L10)

- `isLayoutStabilizing`
  - definition: RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/LayoutStability.swift
  - write: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/SplitBrowserRootView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/SplitBrowserRootView.swift#L148)
  - read: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/BrowserView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/BrowserView.swift#L12)

- `browserLayoutMode`
  - definition: RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/BrowserLayoutEnvironment.swift
  - write: [App/AppRootView.swift](App/AppRootView.swift#L92)
  - read: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Chrome/BrowserChromeView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Chrome/BrowserChromeView.swift#L9)

- `browserWindowID`
  - definition: RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Environment/BrowserEnvironmentKeys.swift
  - write: [App/AppRootView.swift](App/AppRootView.swift#L94)
  - read: [App/Views/SettingsView.swift](App/Views/SettingsView.swift#L13)

- `browserRuntime`
  - definition: RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Environment/BrowserEnvironmentKeys.swift
  - write: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/SafariLikeBrowserView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/SafariLikeBrowserView.swift#L63)
  - read: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/BrowserView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/BrowserView.swift#L7)

- `uxPolicy`
  - definition: RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/UXPolicyEnvironment.swift
  - read: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Header/SafariHeaderView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Header/SafariHeaderView.swift#L18)
  - note: no `.environment(\.uxPolicy, ...)` callsite was found in STRICT scanning, but the key is still used as a read-through to its default.

## EnvironmentValues — Candidate Dead (STRICT)

- `layoutEnvironment`
  - definition: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/BrowserLayoutEnvironment.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/BrowserLayoutEnvironment.swift#L47)
  - STRICT usage scan:
    - no `@Environment(\.layoutEnvironment)` callsites found
    - no `.environment(\.layoutEnvironment, ...)` callsites found

Under STRICT rules, this is the only EnvironmentValues key that appears removable **without touching any other file**.

## UserDefaults / AppStorage (literal keys)

### Keys read (or referenced) with literals

- `app.autofill.enabled`
  - AppStorage declaration: [App/AppSettings.swift](App/AppSettings.swift#L59)
  - reads via UserDefaults fallback:
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/SafariLikeFactory.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/SafariLikeFactory.swift#L135)
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/AppGlue/BrowserSessionProvider.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/AppGlue/BrowserSessionProvider.swift#L63)

- Debug toggles (read-only in code; commonly set externally):
  - `ui.debugOverlayEnabled`
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/BrowserPaneView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/BrowserPaneView.swift#L134)
    - [App/AppRootView.swift](App/AppRootView.swift#L68)
  - `debug.hitTestOverlay`
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Debug/HitTestDebugModifier.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Debug/HitTestDebugModifier.swift#L18)
  - `debug.touchInspector`
    - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Debug/TouchInspectorDebugModifier.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Debug/TouchInspectorDebugModifier.swift#L129)
    - note: documentation comment mentions toggling via `UserDefaults.standard.set` in [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Debug/TouchInspectorDebugModifier.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Debug/TouchInspectorDebugModifier.swift#L143)

### Keys written with literals

- No literal `UserDefaults.standard.set(..., forKey: "...")` callsites were found (the only match is a documentation comment).

## Notification.Name (literal strings)

Literal `Notification.Name("...")` values exist, but post/observe sites frequently use static constants (TOOLING-LIMITED). One strict-literal observe site example:

- observed (literal): [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Discard/DiscardController.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Discard/DiscardController.swift#L53)
  - `forName: Notification.Name("SafariLike.webviewPool.oversubscribed")`

Because posts commonly flow through static names, STRICT classification of “posted but never observed / observed but never posted” is **TOOLING-LIMITED** here.

## Conclusion

- The originally planned PR2 deletion targets (`isLayoutStabilizing`, `keyboardHeight`) are **not dead** on this base.
- The only STRICT-safe EnvironmentValues deletion candidate found is `layoutEnvironment` (no read/write callsites).
- If the goal remains “dead-key cleanup”, PR2 needs re-scoping; otherwise PR2 should be dropped on this base.
