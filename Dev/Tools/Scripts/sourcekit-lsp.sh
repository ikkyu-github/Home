#!/usr/bin/env bash
set -euo pipefail

# Ensure SourceKit-LSP build/index artifacts never land inside the repo.
# This is especially important for SwiftPM workspaces where SourceKit-LSP
# otherwise defaults to writing `.build/index-build` next to Package.swift.

SCRATCH_BASE="${WEBOS_SOURCEKIT_LSP_SCRATCH_PATH:-/var/tmp/webOS/SourceKitLSP}"
mkdir -p "$SCRATCH_BASE"

exec /usr/bin/sourcekit-lsp --scratch-path "$SCRATCH_BASE" "$@"
