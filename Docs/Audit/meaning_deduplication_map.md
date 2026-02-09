# Meaning Deduplication Map (PR-03)

Goal: ensure there is exactly one authoritative type per concept (prefer CoreKit / Contracts), and remove “shadow” types that represent the same meaning.

## Completed

### `PaneID` (pane identity)

**Before**

- `SafariLikeCoreKit.PaneID`
  - Location: `RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Heuristics/WebContextRouter.swift`
  - Meaning: which pane a navigation/tab is associated with.

- `SafariLikeKit.PaneID`
  - Location: `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/SplitPane/SplitPaneTypes.swift`
  - Meaning: same concept (primary/secondary panes), duplicated definition.

**After**

- Authoritative type: `SafariLikeCoreKit.PaneID`
  - Now conforms to `Codable` + `CaseIterable` to support SafariLikeKit’s persistence/state-machine needs.

- Compatibility surface: `SafariLikeKit.PaneID` remains available as:
  - `public typealias PaneID = SafariLikeCoreKit.PaneID`

**Why CoreKit**

- CoreKit already used `PaneID` in WebKit heuristics/routing.
- Consolidation keeps cross-layer meaning consistent and removes duplicated enums.

## Next candidates (not changed yet)

These came from initial scans and should be tackled in small, reviewable batches.

- Policy/decision types: ensure a single source of truth (CoreKit/Contracts) and remove wrappers that don’t add meaning.
- Web view attachment/render state: reconcile overlaps between `WebRenderState` and SafariLikeKit attachment status/state types.
- Duplicate IDs/enums used in journaling/session restore: unify where feasible without breaking persistence formats.
