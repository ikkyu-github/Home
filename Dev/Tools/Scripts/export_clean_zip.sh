#!/usr/bin/env bash
set -euo pipefail

# Deprecated: use Scripts/export_clean.sh
#
# Strategy:
# - Run hygiene checks.
# - Prefer `git ls-files` so we don't accidentally ship build artifacts.
# - Fall back to a conservative `find` when not in a git work tree.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

exec "$ROOT_DIR/Scripts/export_clean.sh"

if ! command -v zip >/dev/null 2>&1; then
  echo "error: zip is not installed" >&2
  exit 1
fi

TS="$(date +%Y%m%d-%H%M%S)"

