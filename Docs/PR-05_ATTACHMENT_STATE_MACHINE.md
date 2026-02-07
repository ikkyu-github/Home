# PR-05 — Attachment Determinism & Re-entrancy Kill (Safari-grade)

This document describes the WKWebView attachment lifecycle state machine implemented in SafariLikeKit’s SwiftUI `WebView` wrapper.

## Goals

- Deterministic, idempotent attach/detach behavior.
- No re-entrancy from SwiftUI update/dismantle call stacks.
- Async race elimination: outdated tasks must never commit state.
- Single-writer: exactly one coordinator mutates attachment state and view hierarchy.

## Single Writer

Only the internal `AttachmentCoordinator` (nested inside `WebView.Coordinator`) may:

- mutate attachment state
- attach/detach `WKWebView` to/from the container UIView
- schedule or cancel attach/detach-related async Tasks
- emit `onAttached` / `onDetached` callbacks

All other layers may only *request* transitions (e.g. `requestAttach`, `requestRestore`, `requestDetach`).

## States

- `idle`: no bound WKWebView.
- `attaching`: WKWebView is attached, but not yet “reality ready”.
- `ready`: WKWebView is attached and reality-ready.
- `detaching`: detach requested and teardown in progress.
- `restoring`: transient SwiftUI unbind (handle becomes nil); hierarchy is preserved to prevent orphaning.
- `failed`: invariant breach detected; best-effort repair may run.

## Reality Ready

A WKWebView is considered ready when:

- it is in the view hierarchy (`superview != nil`)
- it is in a window (`window != nil`)
- it has a non-empty frame
- the container has non-empty bounds

This avoids false “attached” signals during SwiftUI diffing when bounds are temporarily zero.

## Events / Requests

- `requestAttach(webView, container, identity, forceRebind)`: idempotently attach the webview and enter `attaching`.
- `updateReadinessIfPossible(...)`: checks “reality ready”; if ready, transitions to `ready` and schedules `onAttached` once.
- `requestRestore(container)`: handle became nil; transitions to `restoring` but keeps hierarchy intact.
- `requestDetach(container)`: detaches the currently-bound webview (if any), transitions to `idle`, schedules `onDetached`.
- `repairInvariant(...)`: best-effort repair for superview mismatch; transitions to `failed` and attempts to reattach.

## Allowed Transitions (Illegal = No-op)

- `idle -> attaching`
- `idle -> restoring`
- `attaching -> ready`
- `attaching -> restoring`
- `attaching -> detaching`
- `ready -> restoring`
- `ready -> detaching`
- `restoring -> attaching`
- `restoring -> ready`
- `restoring -> detaching`
- `detaching -> idle`
- `any -> failed`
- `failed -> attaching | detaching | restoring | idle` (recovery allowed)

## Idempotency Guarantees

- Calling attach multiple times with the same `(webView, container, identity)` is a no-op.
- Detach during attach cancels in-flight readiness work via generation tokens.
- Discard (e.g. handle becomes nil) transitions to `restoring` and prevents orphaned webviews.

## Async Race Elimination

Every attach/detach request increments a local `generation` counter.

All async Tasks (post-layout readiness checks, deferred callbacks, debug validation/repairs) capture the current token and must verify the token is still current before committing any state or emitting callbacks.
