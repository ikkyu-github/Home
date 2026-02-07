# AddressBar State Machines → UXKit Migration

This workspace is not a Git repo, so there isn’t a native “before/after” history to diff against. This document captures the *structural* change (what moved, where the source of truth lives now, and what shims remain for compatibility), plus commands you can run locally to inspect the relevant files.

## Goals

- UX-focused state machines live in **SafariLikeUXKit**.
- **SafariLikeKit** consumes those state machines (controller + view-model domain glue) and keeps UI code.
- No UIKit/SwiftUI imports in the moved state machine code.

## What Moved

### 1) Entry/editing/suggestions state machine

**New source of truth**:
- `RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/AddressBar/AddressBarEntryStateMachine.swift`
- (Mirror) `SafariLikeUXKit/AddressBar/AddressBarEntryStateMachine.swift`

This is a generic `@MainActor` `ObservableObject` that owns:
- Focus/edit transitions
- Draft vs displayed text
- “select all on focus” intent
- Debounced suggestion requests

**Compatibility shim**:
- `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/AddressBar/AddressBarStateMachine.swift`
- (Mirror) `SafariLikeKit/Runtime/AddressBar/AddressBarStateMachine.swift`

These now `typealias` the old symbol name to the UXKit implementation.

### 2) UI rendering state machine (address bar chrome)

**New source of truth**:
- `RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/AddressBar/AddressBarUIStateMachine.swift`
- (Mirror) `SafariLikeUXKit/AddressBar/AddressBarUIStateMachine.swift`

Types moved into UXKit:
- `AddressBarUIState`
- `AddressBarUIEvent`
- `AddressBarUIStateMachine`

**Consumer updated**:
- `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/ViewModel/SplitBrowser/SplitBrowserAddressBarDomain.swift`
- (Mirror) `SafariLikeKit/ViewModel/SplitBrowser/SplitBrowserAddressBarDomain.swift`

The domain now uses UXKit’s types instead of embedding its own state machine/types.

## Key Wiring Changes

- `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/AddressBarController.swift` now imports `SafariLikeUXKit` and uses `AddressBarEntryStateMachine<SplitBrowserViewModel.OmniboxSuggestion>`.

## Dependency Graph (Conceptual)

### Before

```
SafariLikeKit
  ├─ AddressBarController
  ├─ Runtime/AddressBar/AddressBarStateMachine      (entry/draft/suggestions)
  └─ SplitBrowserAddressBarDomain                    (UI state machine + state/events)

SafariLikeUXKit
  └─ (no canonical AddressBar entry/UI machines)
```

### After

```
SafariLikeUXKit
  ├─ AddressBarEntryStateMachine                     (entry/draft/suggestions)
  └─ AddressBarUIStateMachine + AddressBarUIState/Event

SafariLikeKit
  ├─ AddressBarController  ───── uses ─────▶ AddressBarEntryStateMachine
  ├─ Runtime/AddressBar/AddressBarStateMachine (typealias shim)
  └─ SplitBrowserAddressBarDomain ─ uses ────▶ AddressBarUIStateMachine
```

## Inspecting Changes (Commands)

These are useful local inspection commands (run from repo root):

- See the shim state machine:
  - `sed -n '1,120p' RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/AddressBar/AddressBarStateMachine.swift`

- See the UXKit entry state machine:
  - `sed -n '1,220p' RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/AddressBar/AddressBarEntryStateMachine.swift`

- See the UXKit UI state machine:
  - `sed -n '1,260p' RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/AddressBar/AddressBarUIStateMachine.swift`

- See the domain wiring:
  - `sed -n '1,120p' RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/ViewModel/SplitBrowser/SplitBrowserAddressBarDomain.swift`

If you want “diff-style” output for the migration in this non-git workspace, you can at least produce unified diffs between the shim and the new canonical implementation:

- `diff -u RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/AddressBar/AddressBarStateMachine.swift RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/AddressBar/AddressBarEntryStateMachine.swift | head`

(That diff shows the shim vs the full implementation.)
