# Repo Hygiene

This repository is intentionally kept **free of build artifacts**. Build output is large, machine-specific, and makes reviews + clean exports unreliable.

## Never commit or zip these

**Directories (anywhere in the repo):**
- `.build/` (SwiftPM output)
- `build/` (Xcode output)
- `DerivedData/` (Xcode derived data)
- `__MACOSX/` (macOS Finder/zip metadata)

**Generated file types (anywhere in the repo):**
- `*.pcm`
- `*.swiftmodule`
- `*.swiftdeps`
- `*.dia`
- `*.d`
- `*.timestamp`

These are ignored by `.gitignore` and should never appear in commits.

## Swift Package policy (dependency integrity)

Swift Packages must be added/managed via **Xcode** (Project Settings → Swift Package Dependencies) and must be **remote** packages (e.g. `https://github.com/...`).

Rules:
- No local Swift packages in the Xcode project (`XCLocalSwiftPackageReference` is not allowed).
- Every Swift package product linked by any target must be declared at the **project level**.
- Do not vendor/check in third-party package source or build output into this repo.

`Scripts/repo_guard.sh` enforces this via `Dev/Tools/Scripts/validate_xcode_swift_packages.sh`.

## Editor indexing caches (SourceKit-LSP)

The VS Code Swift extension can run SourceKit-LSP in a mode that writes SwiftPM indexing output under package roots (e.g. `.build/index-build`). This can instantly bloat the working tree and cause `Scripts/repo_guard.sh` to fail.

This repo includes two guardrails to redirect SourceKit-LSP's scratch/build directory **outside the repo**:
- `.vscode/settings.json`: `swift.sourcekit-lsp.serverArguments` includes `--scratch-path /var/tmp/webOS/SourceKitLSP`
- `.sourcekit-lsp/config.json`: sets `swiftPM.scratchPath` to `/var/tmp/webOS/SourceKitLSP`

Because the Swift VS Code tooling often treats each folder containing a `Package.swift` as its own workspace root, the repo also includes per-package configs:
- `RuntimePackages/*/.sourcekit-lsp/config.json`

If you still see `.build/` appearing under `RuntimePackages/*`:
- Reload the VS Code window (settings apply on language server restart)
- Re-run `Dev/Tools/Scripts/clean.sh`

## Size budget (regression detection)

This repo intentionally stays **small (source-only)**. Large repos are harder to review, slower to clone/CI, and make it easy to accidentally ship machine-specific build caches.

`Scripts/repo_guard.sh` enforces a **maximum allowed repo size** (excluding `.git`). If the budget is exceeded, the guard fails and prints the **top 10 largest paths** to help you quickly find what bloated.

**Default budget:** 15 MiB

**Override (local/CI) if needed:** set `WEBOS_MAX_REPO_SIZE_MIB` to an integer MiB value.

## Clean the repo (idempotent)

Run:
- `Dev/Tools/Scripts/clean_repo.sh`

This removes known build/log artifacts from the working tree.

## Verify the repo is clean (CI-safe)

Run:
- `Scripts/check_repo_clean.sh`

This script scans for forbidden build artifact directories and generated files and exits non-zero if any are found.

## Package/export a clean project zip

**Official (only supported) method:**
- `Scripts/export_clean.sh`

This produces a zip that is:
- Pre-cleaned (removes known artifacts)
- Guarded (fails if forbidden artifacts exist)
- Validated (fails if the zip contains forbidden artifacts)

### Clean Export policy

**Included:** source files, assets, configs, docs, and project metadata required to open/build (e.g. `*.swift`, `*.plist`, `*.entitlements`, `Package.swift`, `.xcodeproj` metadata, `.xcassets`, scripts).

**Must be excluded (always, anywhere in the tree):**
- Directories: `.build/`, `build/`, `DerivedData/`, `build_logs/`, `IncomingLogs/`, `xcuserdata/`, `.swiftpm/`, `__MACOSX/`, `.git/`
- Generated/compiled outputs: `*.pcm`, `*.swiftmodule`, `*.swiftdeps`, `*.dia`, `*.d`, `*.timestamp`, `*.xcresult`, `*.xcactivitylog*`, `.DS_Store`

### Sharing rule

Sharing the project as a zip is supported **only** via `Scripts/export_clean.sh`. Any other zip workflow is considered invalid because it can silently reintroduce build artifacts.
