# PR9 — UX Policy Centralization: Regression Checklist

Goal: validate that UI behavior is policy-driven and stable across rotation, focus changes, and layout modes.

## 1) Address Bar + Keyboard

- Tap the address field (TopBar / bottom bar)
  - Keyboard appears; caret visible; text selection behavior is deterministic (select-all on focus where applicable).
  - “Cancel” appears only after the configured reveal threshold.
- Tap outside the address field
  - Keyboard dismisses and the UI returns to passive state.
  - No chrome height jump (especially after rotation).
- Submit URL/search (Return key)
  - Navigates once; editing ends; keyboard dismisses.

## 2) Back/Forward Swipe vs Scroll View

- In a page with horizontal/vertical scroll content:
  - Edge swipe (left edge) triggers back only when gesture begins inside edge zone.
  - Edge swipe respects horizontal intent (should not trigger on mostly-vertical swipes).
- Verify the same in both phone portrait and iPad landscape layouts.

## 3) Tab Overview: Animation + State Consistency

- Open Tab Overview via toolbar/menu
  - Overview presents cleanly; no invisible hit-test blocker remains after dismissal.
  - Drag gestures inside overview feel consistent (no accidental dismissal / no stuck half-state).
- Dismiss Tab Overview
  - Web content becomes interactive immediately.
  - No duplicate “activate tab” side effects.

## 4) Split / Layout Modes

- iPad landscape:
  - Sidebar presentation follows resolved policy (no bottom overlay for Related when in sidebar mode).
  - Split toggle behavior respects min width policy.
- Phone portrait:
  - Related presents only as bottom overlay (never reserves width as a side pane).

## 5) Rotation Sanity

- Rotate portrait ↔ landscape while:
  - Address bar is focused
  - Tab overview is presented
  - Related is presented

Expected:
- No ghost gaps/blank bands; no stuck overlays; no “half-presented” overview.
- UI remains tappable (no orphaned full-screen hit-test view).

## 6) Policy Toggles (optional / debug)

If you have a debug path to modify resolved `UXPolicy` at runtime:
- Set `uxPolicy.tabOverview.isEnabled = false`
  - Tab Overview entry points should disappear (menu/buttons) and no longer be triggerable from UI.
