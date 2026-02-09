# ZipExportPolicy

This document defines how we export a runtime-only deliverable as `OS.zip`.

## Goals

- Produce a distributable zip after a successful build.
- Include only runtime deliverables (the built app + runtime frameworks + enabled plugin bundles).
- Exclude developer-only content (`Dev/`, tests, docs, diagnostics).

## Artifact

- Output: `build/OS.zip`
- Source: `$(TARGET_BUILD_DIR)/$(FULL_PRODUCT_NAME)` (the built `.app` bundle)

## Included content (must)

- The app bundle itself: `webOS.app` (or `$(FULL_PRODUCT_NAME)`).
- Runtime frameworks embedded in the app: `*.framework` under `webOS.app/Frameworks/`.
- Enabled plugin bundles/frameworks embedded in the app.

## Excluded content (must not)

These must not appear in `OS.zip`:

- Any repo developer folders or sources: `Dev/**`, `**/*Tests/**`, `Dev/Docs/**`.
- Diagnostics/dev tooling accidentally copied into the app bundle.

Note: the export process zips the built `.app` bundle, so these items should not be present unless the app build copies them into the bundle.

## Enabled plugins

Enabled plugin IDs are taken from the app’s `Info.plist` key:

- `SafariLikeEnabledPluginIDs` (array of strings)

For *embedded plugin bundles/frameworks*, the export step may prune disabled plugins:

- Any embedded bundle/framework that declares `SafariLikePluginID` in its own `Info.plist` is considered a plugin payload.
- If its `SafariLikePluginID` is not in `SafariLikeEnabledPluginIDs`, it is removed from the staged export before zipping.

Built-in (compiled-in) plugins are governed at runtime by the allowlist, but are not physically removable from the binary during export.

## Size policy

`OS.zip` size is validated after export.

- Default maximum: 200 MB
- Override via environment variables:
  - `OS_ZIP_MAX_MB` (integer)
  - or `OS_ZIP_MAX_BYTES` (integer)

## How it runs

The webOS Xcode target includes a “Run Script” build phase that:

1. Runs `Dev/Tools/export_os_zip.sh`.
2. Produces `build/OS.zip`.
3. Validates the zip size.

By default, export runs only for `Release` builds.

Override behavior:

- Set `EXPORT_OS_ZIP_ALWAYS=1` to run for any configuration.
