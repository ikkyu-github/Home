#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage:
  Dev/Tools/Scripts/spm.sh <package-path> <build|test|clean|resolve> [extra swift args...]

Runs SwiftPM with build output redirected OUTSIDE the repo.

Environment variables:
  WEBOS_SWIFTPM_CACHE_DIR  Override base cache dir (default: ~/Library/Caches/webOS/SwiftPM)
EOF
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

PKG_REL="${1:-}"
CMD="${2:-}"
shift 2 || true

if [[ -z "$PKG_REL" || -z "$CMD" ]]; then
  usage
  exit 2
fi

# SourceKit-LSP and other tooling can create SwiftPM caches under package roots
# (notably `.build/index-build`). Keep the repo clean and keep repo_guard useful
# by proactively cleaning before we validate.
"$ROOT_DIR/Dev/Tools/Scripts/clean.sh" || true

if ! "$ROOT_DIR/Scripts/repo_guard.sh"; then
  # One more attempt in case of concurrent index-build writes.
  "$ROOT_DIR/Dev/Tools/Scripts/clean.sh" || true
  "$ROOT_DIR/Scripts/repo_guard.sh"
fi

PKG_PATH="$ROOT_DIR/$PKG_REL"
if [[ ! -d "$PKG_PATH" ]]; then
  echo "[spm][ERROR] package path not found: $PKG_PATH" >&2
  exit 2
fi

PKG_NAME="$(basename "$PKG_PATH")"
CACHE_BASE="${WEBOS_SWIFTPM_CACHE_DIR:-$HOME/Library/Caches/webOS/SwiftPM}"
SCRATCH="$CACHE_BASE/$PKG_NAME"
mkdir -p "$SCRATCH"

echo "[spm] repo: $ROOT_DIR"
echo "[spm] package: $PKG_REL"
echo "[spm] scratch: $SCRATCH"

case "$CMD" in
  build|test|clean|resolve) ;;
  *)
    echo "[spm][ERROR] unsupported command: $CMD" >&2
    usage
    exit 2
    ;;
 esac

set +e
swift "$CMD" --package-path "$PKG_PATH" --scratch-path "$SCRATCH" "$@"
status=$?
set -e

"$ROOT_DIR/Dev/Tools/Scripts/clean.sh" || true
"$ROOT_DIR/Scripts/repo_guard.sh"

exit $status
