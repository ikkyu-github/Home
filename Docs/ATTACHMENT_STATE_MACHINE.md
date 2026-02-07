# Attachment State Machine (Safari-like)

This document defines the deterministic attachment lifecycle for a tab’s `WKWebView` *attachment* in webOS.

## Goals

- **Single writer:** only `AttachmentCoordinator` mutates attachment state.
- **Deterministic transitions:** repeated calls are **idempotent** (no-op when already satisfied).
- **Race elimination:** async work cannot “commit” stale state (generation tokens + re-read-after-yield publishing).
- **UI safety:** state publication to SwiftUI is deferred to avoid publish-during-update cycles.

## Key types

- `WebViewAttachmentState`
  - `.idle`
  - `.attaching`
  - `.ready`
  - `.restoring(snapshot: Data)`
  - `.timedOut`
  - `.failed(reason: String)`
- `WebViewAttachmentStatus` (tab-scoped state + timestamp)

## Ownership boundaries

### Allowed writers

- `AttachmentCoordinator` is the only component allowed to transition attachment state.

### Allowed requestors (no direct writes)

- `SceneRuntimeContext` wires runtime signals (tab activation, view attach/detach, app active/background) into the coordinator.
- `AppLifecycleCoordinator.updateAttachmentState(...)` is an **escape hatch** but is implemented as a *request* (`requestRuntimeStateOverride`) into the per-scene coordinator.
- `TabManager.forceAttachActiveTabWebView(...)` requests `.attaching` via coordinator override.

## State machine

### States

- **`idle`**
  - No attached `WKWebView` is required/expected.
  - May also represent a detached/warm state (depending on store policy), but from UI perspective it is “not attached”.

- **`attaching`**
  - An attach has been requested and is expected to complete.
  - Watchdog timeout applies.

- **`ready`**
  - The `WKWebView` is attached and usable for interactive browsing.

- **`restoring(snapshot)`**
  - Transitional state used while restoring from snapshot bytes.
  - Allowed to move back to `ready` or to `attaching` depending on reality signals.

- **`timedOut`**
  - Attach attempt exceeded deadline.
  - May be followed by a throttled soft recover (re-request attach).

- **`failed(reason)`**
  - Terminal-ish state for the current attempt; may be followed by retry.

### Allowed transitions (coordinator enforced)

Notation: `A → B` means transition from `A` to `B`.

- `idle → attaching`
  - Trigger: active tab requires webview; UI/root view wants web content.

- `attaching → ready`
  - Trigger: reality signals confirm handle/attachment complete.

- `attaching → timedOut`
  - Trigger: watchdog timeout fires (generation-guarded).

- `ready → idle`
  - Trigger: tab no longer requires webview (overview/snapshot-only/background-hidden), or explicit detach request.

- `ready → restoring(snapshot)`
  - Trigger: restore pipeline begins.

- `restoring(snapshot) → ready`
  - Trigger: restore completes / reality confirms ready.

- `restoring(snapshot) → attaching`
  - Trigger: restore requires re-attach (e.g. missing handle).

- `timedOut → attaching`
  - Trigger: throttled soft-recover (retry attach).

- `failed → attaching`
  - Trigger: retry requested.

### Idempotency rules

- Requesting the current state is a **no-op** (no new watchdog, no extra publishes).
- `detach` / `discard` operations at the store level are **idempotent** and invalidate in-flight activation (see generation notes below).
- Coordinator publishing is **deduped** by semantic equivalence (`equivalentState`), not by exact associated values where appropriate.

### Illegal / discouraged transitions

- Direct external writes (e.g. `SceneRuntimeContext.currentAttachmentStatus = ...`) are not allowed.
- Publishing state synchronously inside view update cycles is discouraged; publication is deferred (`Task { @MainActor; await Task.yield() }`).

## Race suppression

### Coordinator-side

- **Generation token per tab** (attachment attempt generation):
  - Starting an attach bumps generation.
  - Watchdog timeout callback checks `expectedGeneration` matches the current record before committing `timedOut`.

- **Re-read-after-yield publishing:**
  - The coordinator yields to avoid SwiftUI publish-during-update.
  - After yielding it **re-reads the latest record** before emitting, so outdated async tasks cannot publish stale state.

### Store-side (`TabWebStore`)

- **Lifecycle generation token (`webViewLifecycleGeneration`)**:
  - `activate(using:)` captures generation before awaiting `WebContextRouter`.
  - After await, it checks generation; if invalidated by `deactivate` / `detach` / `discard`, activation aborts safely.
  - `deactivate(releaseMode:)`, `detachWebViewForBackground()`, and `discardWebViewInternal()` all bump generation (even if no webview exists yet).

## Debugging tips

- If you see “attach-after-discard” symptoms, verify generation bumps on every detach/discard path.
- If you see UI flicker or re-entrant view updates, verify coordinator emission is deferred and deduped.
