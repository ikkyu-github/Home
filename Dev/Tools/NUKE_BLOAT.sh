#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

APPLY=0
KEEP_DEV_BACKUPS=0

usage() {
  cat <<'USAGE'
Usage:
  ./NUKE_BLOAT.sh [--apply] [--keep-dev-backups]

Behavior:
  - Safe by default: runs in DRY-RUN mode unless you pass --apply
  - Deletes only build/cache/archive/backup artifacts (never targets source files)
  - Echoes every deletion (or would-delete)
  - Idempotent: can be run repeatedly

Examples:
  ./NUKE_BLOAT.sh
  ./NUKE_BLOAT.sh --apply
  ./NUKE_BLOAT.sh --apply --keep-dev-backups
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    --keep-dev-backups)
      KEEP_DEV_BACKUPS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

log_rm() {
  local path="$1"
  if [[ $APPLY -eq 1 ]]; then
    echo "rm -rf -- $path"
  else
    echo "[dry-run] rm -rf -- $path"
  fi
}

rm_rf() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    log_rm "$path"
    if [[ $APPLY -eq 1 ]]; then
      rm -rf -- "$path"
    fi
  fi
}

# 1) Known top-level build output folder
rm_rf "build"

# 2) Known dev backup/orphan folders (optional keep)
if [[ $KEEP_DEV_BACKUPS -eq 0 ]]; then
  rm_rf "Dev/PBXBackups"
  rm_rf "Dev/_orphaned"
fi

# 3) Xcode/SwiftPM build & cache directories (any depth)
#    NOTE: We only target directory names / known artifact suffixes.
while IFS= read -r -d '' d; do
  rm_rf "$d"
done < <(
  find . \
    -type d \( \
      -name '.build' \
      -o -name '.swiftpm' \
      -o -name 'DerivedData' \
      -o -name 'ModuleCache.noindex' \
      -o -name 'Index.noindex' \
      -o -name 'xcuserdata' \
      -o -name '*.xcarchive' \
      -o -name '*.dSYM' \
      -o -name '*.app' \
      -o -name '*.framework' \
      -o -name '*.xcframework' \
      -o -name '*.xctest' \
    \) \
    -not -path './.git/*' \
    -prune -print0 2>/dev/null
)

# 4) Common artifact files (logs/index DBs/user state)
#    Avoids touching source files (.swift/.plist/.json). Only removes known junk.
while IFS= read -r -d '' f; do
  rm_rf "$f"
done < <(
  find . \
    -type f \( \
      -name '.DS_Store' \
      -o -name '*.xcactivitylog' \
      -o -name '*.xcuserstate' \
      -o -name '*.xccheckout' \
      -o -name '*.swp' -o -name '*.swo' \
      -o -name '*.ipa' \
    \) \
    -not -path './.git/*' \
    -print0 2>/dev/null
)

if [[ $APPLY -eq 1 ]]; then
  echo "Done. (Applied deletions)"
else
  echo "Done. (Dry-run only; re-run with --apply to delete)"
fi
