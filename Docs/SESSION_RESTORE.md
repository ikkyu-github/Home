# Session Restore (Safari-like)

This repo uses a file-backed, per-scene/window session snapshot to support Safari-like cold-start session restore.

## What is persisted

The single authoritative snapshot model is `BrowserCore.WindowSessionState`.

It persists only durable, non-derived state:

- Tab list order and minimal tab metadata (`BrowserTab`: id/title/urlString/pinned/etc)
- Selected tab id
- Tab groups and selection
- Bounded recently-closed stack
- Durable per-tab navigation state (`tabNavigationByID`)
- Window UI/layout state (`splitView`, `ui`)

## Where it is stored

Per-scene snapshots are stored in `BrowserCore.SceneSessionStore` using a directory bucket under **Application Support**:

- `sessions/<scene>/tabs.json`
- `sessions/<scene>/groups.json`
- `sessions/<scene>/nav_state.json`
- `sessions/<scene>/recently_closed.json`
- `sessions/<scene>/continue_browsing.json`
- `sessions/<scene>/meta.json` (schema version + lastSavedAt)

Older builds may have persisted buckets under Documents; `SceneSessionStore` performs a best-effort migration to Application Support when loading.

## Cold start discipline (multi-scene)

Restore is staged:

- The model snapshot is loaded first (`BrowserSessionStore.awaitInitialLoad()`).
- Only visible/active panes acquire live `WKWebView` instances after restore completes.
- Background tabs remain placeholders until activated; WebView creation remains centralized in the WebView pool.

## Safety and budgets

`SceneSessionStore` applies persistence budgets on save:

- Caps the number of persisted tabs (keeps the selected tab when trimming)
- Caps the recently-closed stack
- Drops durable navigation state for tabs that are not persisted

It also performs deterministic cleanup by pruning old per-scene buckets beyond a fixed limit.

## Corruption handling

All disk reads are best-effort.

- If a bucket is missing or corrupted, restore falls back to a single placeholder tab.
- Individual corrupt tab/group entries are decoded lossily so they don't nuke the entire window.
