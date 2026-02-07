# Session Journal Restore (Crash-Safe)

This project restores session structure from an **append-only journal** (and its archived segments), then lazily re-attaches WebKit only for visible panes.

## Files

- [RuntimePackages/BrowserCore/Sources/BrowserCore/Session/Journal/SessionJournal.swift](../RuntimePackages/BrowserCore/Sources/BrowserCore/Session/Journal/SessionJournal.swift)
- [RuntimePackages/BrowserCore/Sources/BrowserCore/Session/Journal/SessionRestorer.swift](../RuntimePackages/BrowserCore/Sources/BrowserCore/Session/Journal/SessionRestorer.swift)
- [RuntimePackages/BrowserCore/Sources/BrowserCore/Session/Restore/SessionReplayEngine.swift](../RuntimePackages/BrowserCore/Sources/BrowserCore/Session/Restore/SessionReplayEngine.swift)
- [RuntimePackages/BrowserCore/Sources/BrowserCore/Session/Restore/SessionReducer.swift](../RuntimePackages/BrowserCore/Sources/BrowserCore/Session/Restore/SessionReducer.swift)

## Replay Flow

```mermaid
flowchart TD
  A[App launch] --> B[Read journal segments]
  B --> C[Parse framed records]
  C -->|bad tail| D[Truncate active tail to last-good offset]
  C --> E[Deterministic sort]
  E --> F[Reduce events into SessionState]
  F --> G[SessionRestorePlan]
  G --> H[Phase A: UI placeholders]
  H --> I[Phase B: activate visible panes only]
  I --> J[Phase C: lazy activation on selection]
```

## Event Categories

- **Structural**: `windowCreated`, `splitModeChanged`, `tabCreated`, `tabMovedPane`, `tabClosed`
- **Selection/focus**: `paneFocusChanged`, `tabSelected`
- **Navigation**: `navigationCommitted` / `urlCommitted`
- **Lifecycle**: `tabSuspended`, `tabDiscarded`

## Crash Safety

- Each journal record is framed (`JRNL` header + payload length + CRC32) so a crash mid-write leaves an incomplete final record.
- On read, the parser stops at the first invalid record and truncates only the active tail file back to the last known-good boundary.
