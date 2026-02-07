# Downloads Storage Policy

This repo intentionally separates **durable** downloads (regular browsing) from **ephemeral** downloads (private browsing) to avoid cross-launch leakage and to keep cleanup/budgets enforceable.

## Storage layout

Download storage is owned behind the `SafariLikeContracts.DownloadFileIO` boundary.

### Regular mode (durable)

- Root: `Application Support/`
- Folder: `Downloads/`
- Resume data: `Downloads/.resume-data/`

Regular downloads are eligible for persistence and for file-list presentation in the downloads UI.

### Private mode (ephemeral)

- Root: `Caches/` (fallback: `temporaryDirectory`)
- Folder: `DownloadsTemp/`
- Resume data: `DownloadsTemp/.resume-data/`

Private-mode downloads are intentionally written only into ephemeral locations.

## Budgets & cleanup

`SafariLikeKit.DefaultDownloadFileIO.Options` defines best-effort budgets:

- `persistentMaxFileCount` (default: `200`)
- `persistentMaxTotalBytes` (default: `512 MiB`)
- `temporaryMaxAge` (default: `24h`)

`BrowserCore.DownloadCenter` will call `DownloadStorageMaintaining.pruneStorage(now:)` on bootstrap when the injected file IO supports it.

## Privacy guarantees

- Private download records are never written to persisted download state.
- `DownloadCenter.purgePrivateDownloads(sceneID:)` performs a best-effort on-disk purge of:
  - private destination files
  - private resume data
  - in-memory private records/snapshots

## Filename hygiene

`DefaultDownloadFileIO` sanitizes suggested filenames to avoid path traversal and unsafe filesystem characters (e.g. `/`, `\\`, `:`) and applies a conservative length cap.
