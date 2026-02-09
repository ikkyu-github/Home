# Safari Parity Checklist

Generated: 2026-02-03

This is a pragmatic checklist to validate “Safari-like” runtime determinism and UI behavior.

## Render budget / activation
- [ ] Single authority for render budgeting (CoreKit policy + runtime apply)
- [ ] No UI-driven activation/detach side effects (no `onAppear` budget enforcement)
- [ ] At most N active WebViews per scene (budget applies per scene, not globally)
- [ ] Overflow tabs transition to suspended/snapshot state without attaching WKWebView

## Overview rules (hard constraints)
- [ ] Tab overview never triggers WebView activation
- [ ] While overview is visible, runtime does not perform background “recovery activation”
- [ ] Any detach/freeze operations route through registry/coordinator (no bypasses)

## Attachment determinism (single-writer)
- [ ] Only `AttachmentCoordinator` mutates attachment state
- [ ] Generation tokens prevent stale async commits (attach-after-discard, detach-after-recover)
- [ ] Detach/discard operations are idempotent and bump generation
- [ ] Publishing to SwiftUI occurs after `Task.yield()` to avoid update-pass mutation

## Scene isolation
- [ ] Each scene has its own runtime context and registries
- [ ] No cross-scene shared mutable state controlling WebView attachment

## Policy-driven UI
- [ ] UI decisions are stored as value-type Decisions in ViewModels
- [ ] Decisions are computed from snapshots (no implicit side effects)
- [ ] BrowserPaneView does not reach into WKWebView internals to decide renderability

## Contracts stability
- [ ] Public contracts remain in the Contracts/CoreKit layers
- [ ] Deprecated shims are either unused or have explicit migration paths

## Regression checks (manual / UI)
- [ ] Launch → new tab → load URL; no unexpected overview activation
- [ ] Rapid tab switching does not produce double-attach or stuck unbound states
- [ ] Background/foreground scene transitions do not break attachment invariants
- [ ] Rotation stress: stable insets/size settle and UI remains responsive
