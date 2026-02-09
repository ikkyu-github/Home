# Duplication Report

Generated: 2026-02-03

## Theme: single authority + snapshot→decision→apply
The main duplication risk in this codebase comes from having multiple layers “decide” the same thing (budgeting, activation, visibility) with slightly different rules.

## Resolved duplication (completed)
### Render budget authority
- **Before**: `RenderPolicyManager` in SafariLikeKit UI enforced a local LRU budget by mutating `WebContext.renderState` on `onAppear/onDisappear`.
- **Also present**: CoreKit `RenderBudgetPolicy` (pure) and runtime enforcement in `SafariLikeKit/Runtime/TabLifecycleController`.
- **Problem**: two authorities, side effects during UI updates, and unit tests drifting against an older API.
- **After**: removed the UI-owned `RenderPolicyManager` path so budgeting remains owned by CoreKit+runtime.

## Active duplication candidates (not yet modified)
### “Requires WebView” vs “Should show web content”
- There are now explicit policies:
  - `WebViewRequirementPolicy` (derived from tab state)
  - `WebContentVisibilityPolicy` (derived from runtime reality)
- Risk: other code paths may still infer these ad-hoc (e.g. `tabState` checks in views).
- Suggested follow-up: grep for `StartPage` / `requiresWebView` / `shouldShowWebContent` patterns and converge them on policy calls.

### Split/related presentation policies
- Several resolvers exist:
  - `RelatedPresentationPolicy` and `RelatedPresentationResolver`
  - `BrowserLayoutResolver`, `PaneLayoutResolver`, `SplitViewPolicy`
- Risk: multiple “width threshold” constants drifting.
- Suggested follow-up: centralize thresholds in a single policy type (or re-export one canonical resolver API).

### Extension/helper duplication
- SafariLikeKit contains multiple `extension View { ... }` helpers in:
  - Diagnostics overlays
  - Shared view utilities
- Risk: similar modifiers re-implemented in multiple files.
- Suggested follow-up: group shared view modifiers under one module/folder (e.g. `UI/Modifiers`) and keep Diagnostics overlays private.

## Test duplication / drift
- The removed RenderPolicyManager tests were testing a legacy API.
- Suggested follow-up: ensure budgeting invariants are tested at the runtime/policy boundary instead:
  - CoreKit `RenderBudgetPolicy.decide` tests (pure)
  - Runtime `TabLifecycleController` integration tests (if present/feasible)

## Recommendation
When deciding whether something is duplication vs necessary layering:
- Keep **policies** pure (`Input → Decision`).
- Keep **runtime** as the single writer applying decisions.
- Keep **views** declarative and read-only with respect to lifecycle/budget.
