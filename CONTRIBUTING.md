# Contributing

## Zero-warning policy (hard rule)

This repository enforces a **0 warnings** policy.

- Builds and tests must produce **no** `warning:` lines.
- Pull requests that introduce warnings are **rejected**.
- Do **not** “fix” warnings by disabling diagnostics globally. Fix the root cause instead.

### Local verification

Run an Xcode build that fails the moment warnings exist:

```bash
Dev/Tools/Scripts/xcodebuild.sh --fail-on-warnings clean build
```

If you already have a build log and want to check it directly:

```bash
Dev/Tools/Scripts/check_no_warnings.sh "$HOME/Library/Logs/webOS/xcodebuild-webOS.log"
```

### What counts as a warning?

Any line containing `warning:` in the Xcode build output is treated as a warning (compiler warnings, tool warnings, and accidental script output).

If a script prints something like `warning: ...`, CI will fail—use `note:` or `info:` for non-fatal messages.

## Architecture boundaries (App / Kit / CoreKit)

Keep dependencies one-way:

- **App/**: app entry points, scenes, app-level wiring. Can depend on Kit.
- **SafariLikeKit**: SwiftUI/UI composition + bridges/adapters. Must not decide runtime policy.
- **SafariLikeCoreKit**: runtime policy + budgeting + pooling + activation decisions.

Rule of thumb: **UI renders and emits events; CoreKit decides what happens.**

## Rule: WKWebView allocation only in WebViewPool.swift

- **Hard rule:** do not construct `WKWebView` in Kit/UI code.
- Allocation must happen in **CoreKit** only, via `WebViewPool`.
- Kit receives a handle/reference produced by CoreKit/Pool and only attaches/detaches/configures UI-side wrappers.

Acceptance check:

- No `WKWebView()` (or `.init(...)`) in SafariLikeKit.

## Rule: UI emits events, CoreKit decides activation/budget

- UI layer may:
	- emit intent/events (tap/focus/swipe/scroll/refresh)
	- query read-only state via closures (e.g. “is active pane?”)
- UI layer must not:
	- activate tabs
	- prewarm/allocate web views
	- enforce budgets

Plumb events to CoreKit through ViewModel/Coordinator interfaces; keep decisions in CoreKit.

## Rule: Singletons must not hold scene/tab mutable state

- Singletons are allowed for:
	- stateless helpers
	- read-only registries
	- process-wide diagnostics/invariants
- Singletons must not store mutable per-scene/per-tab state (anything that changes with navigation/selection/activation).

If you need mutable state, keep it in CoreKit runtime objects scoped to scene/tab/window.

## Repo bloat rules

- Do not commit build artifacts (e.g. `DerivedData/`, `.build/`, `*.xcresult`, `*.log`, `*.dSYM`).
- If you accidentally generate artifacts, clean them before committing.
- Use the repository guard scripts and keep them passing:

```bash
bash Scripts/repo_guard.sh
Dev/Tools/Scripts/xcodebuild.sh --fail-on-warnings clean build
```
