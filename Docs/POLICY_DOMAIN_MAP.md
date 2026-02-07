# Policy Domain Map (Safari-like)

This document maps the main policy domains in webOS and where decisions are made.

Principles:
- Policies evaluate **snapshots** (value types) and return **Decisions** (value types).
- Policy evaluation is **synchronous** and **side-effect free**.
- Runtime/UI layers apply decisions declaratively (may perform effects), but do not “peek into” policy internals.

## Domains

## 1) Navigation Policy (Allow/Block/Redirect/New Window)

- **Owner:** SafariLikeCoreKit
- **Files:**
  - [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Policy/SafariNavigationPolicyLayer.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Policy/SafariNavigationPolicyLayer.swift)
  - [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Policy/PolicyCenter.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Policy/PolicyCenter.swift)
- **Snapshot:** `NavigationPolicyInput` + `NavigationPolicy`
- **Decision:** `NavigationPolicyDecision` (outcome + reason + echoed inputs)
- **Evaluator:** `SafariNavigationPolicyEvaluator.evaluate(policy:input:)` (pure)

## 2) Render Budget Policy (How many live WKWebViews)

- **Owner:** SafariLikeCoreKit (policy), SafariLikeKit (application)
- **Files:**
  - [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Policy/RenderBudgetPolicy.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Policy/RenderBudgetPolicy.swift)
  - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabLifecycleController.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabLifecycleController.swift)
- **Snapshot:** `RenderBudgetPolicy.Input` + candidate tab IDs
- **Decision:** `RenderBudgetPolicy.Decision` (keepRendered/freeze/evict)
- **Evaluator:** `RenderBudgetPolicy.decide(input:candidates:)` (pure)
- **Applier:** `TabLifecycleController.applyRenderBudget(reason:)` enforces freeze/activate/renderMode updates.

## 3) Attachment State Policy (Attach/Detach/Timeout/Recover)

- **Owner:** SafariLikeKit
- **Files:**
  - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Lifecycle/AttachmentCoordinator.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Lifecycle/AttachmentCoordinator.swift)
  - [Docs/ATTACHMENT_STATE_MACHINE.md](Docs/ATTACHMENT_STATE_MACHINE.md)
- **Snapshot inputs:** reality + restore state + per-tab IO signals
- **Decision/State:** `WebViewAttachmentState` / `WebViewAttachmentStatus`
- **Rule:** single-writer in `AttachmentCoordinator` with generation-guarded async.

## 4) UI WebView Requirement Policy (Does this tab need WebKit?)

- **Owner:** SafariLikeKit
- **Files:**
  - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Policy/WebViewRequirementPolicy.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Policy/WebViewRequirementPolicy.swift)
- **Snapshot:** `BrowserTab.State?`
- **Decision:** `WebViewRequirementPolicy.Decision` (required / notRequired)
- **Evaluator:** `WebViewRequirementPolicy.decide(tabState:)` (pure)

## 5) UI Web Content Visibility Policy (Prefer web surface vs Start Page overlays)

- **Owner:** SafariLikeKit
- **Files:**
  - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Policy/WebContentVisibilityPolicy.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Policy/WebContentVisibilityPolicy.swift)
  - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/ViewModel/SplitBrowserViewModel.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/ViewModel/SplitBrowserViewModel.swift)
- **Snapshot:** `WebContentVisibilityPolicy.Snapshot(hasLiveWebViewHandle: Bool)`
- **Decision:** `WebContentVisibilityPolicy.Decision` (showWebContent / showNonWebContent)
- **Evaluator:** `WebContentVisibilityPolicy.decide(_:)` (pure)

## 6) Layout / Related / Companion Presentation Policies

- **Owner:** SafariLikeKit / SafariLikeUXKit
- **Examples:**
  - `BrowserLayoutResolver` + `PaneLayoutResolver`
  - `RelatedPresentationPolicy` / `RelatedPresentationResolver`
  - `SplitViewPolicy`
- **Notes:** These are already mostly snapshot->value decisions; follow the same discipline (no side effects in evaluators).

## 7) Background Throttling / Engine Budget

- **Owner:** SafariLikeCoreKit
- **Files:**
  - [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Engine/EngineController.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Engine/EngineController.swift)
- **Notes:** App foreground/background transitions are routed by lifecycle layers; engine policy decisions should remain snapshot-driven.

## 8) Tab Resource / Performance Tier / Discard Policy (Freeze/Evict/Detach)

- **Owner:** SafariLikeKit (application), SafariLikeCoreKit + BrowserCore (policy)
- **Files (examples):**
  - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/TabResourcePolicy.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/TabResourcePolicy.swift)
  - [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Lifecycle/SceneRuntimeContext.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Lifecycle/SceneRuntimeContext.swift)
  - [RuntimePackages/BrowserCore/Sources/BrowserCore/Policy/TabDiscardPolicy.swift](RuntimePackages/BrowserCore/Sources/BrowserCore/Policy/TabDiscardPolicy.swift)
  - [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Discard/SmartDiscardPolicy.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Discard/SmartDiscardPolicy.swift)
- **Snapshot:** visibility/active tab IDs + memory/thermal pressure + per-tab signals
- **Decision:** freeze/evict/discard plan (value type), applied by runtime layers
- **Notes:** Performance tier transitions should be derived from visible/active snapshot (pure), then applied to live stores. Avoid UI-driven implicit detach/evict.
