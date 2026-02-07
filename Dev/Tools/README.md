# Dev Tools

This folder contains workspace utilities used to keep the repo clean and the architecture refactors evidence-based.

## Common scripts (recommended)

All scripts live in `Dev/Tools/Scripts/`.

- `assert_no_bloat.sh` — fails if forbidden build artifacts are present (e.g. `.build/`, `DerivedData/`).
- `clean.sh` — best-effort cleanup of local build artifacts.
- `xcodebuild.sh` — wrapper for consistent `xcodebuild` invocation/log tailing.
- `export_clean_zip.sh` — deprecated wrapper; use `Scripts/export_clean.sh`.

## Architecture / duplication scanners (PR0)

These are **read-only** scanners intended to produce evidence for PR planning.

- `architecture_scan.py`
  - Writes: `Docs/Architecture/phase0_scan_report.md`
  - Run: `python3 Dev/Tools/Scripts/architecture_scan.py --root . --out Docs/Architecture/phase0_scan_report.md`

- `dup_analyze.py`
  - Reports exact duplicates, similar same-basename pairs, and copy/paste clone blocks.
  - Run: `python3 Dev/Tools/Scripts/dup_analyze.py --root .`

- `duplicate_scan.py`
  - Scans CoreKit/UIKit/Kit roots for exact duplicate Swift files and duplicate extension blocks.
  - Run: `python3 Dev/Tools/Scripts/duplicate_scan.py`

- `scan_duplicate_swift.py`
  - Finds Swift files outside `RuntimePackages/**/Sources/**` that byte-match canonical package sources.
  - Run: `python3 Dev/Tools/Scripts/scan_duplicate_swift.py`

- `forbid_duplicate_basenames.sh`
  - Fails if any two Swift files under a root share the same basename (prevents Xcode duplicate output issues).
  - Run: `bash Dev/Tools/Scripts/forbid_duplicate_basenames.sh RuntimePackages`

## Notes

- Keep temporary logs/artifacts out of git. `.gitignore` is treated as policy.
- Prefer running `Dev/Tools/Scripts/assert_no_bloat.sh` before making large refactors.
