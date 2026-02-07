#!/usr/bin/env bash
set -euo pipefail

# clean_before_zip.sh
#
# Goal: make a "shareable" repo state before zipping by removing build artifacts/caches.
# Safe-by-default: DRY-RUN unless you pass --apply.
#
# Typical usage:
#   ./clean_before_zip.sh --apply
#   ./clean_before_zip.sh --apply --keep-dev
#

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage:
  ./clean_before_zip.sh [--apply] [--keep-dev] [--remove-vscode] [--global-deriveddata]

Default is DRY-RUN.

Removes (when enabled):
- SwiftPM artifacts/caches: **/.build, **/.swiftpm
- Xcode in-repo artifacts: build/, DerivedData/, ModuleCache*, *.xcresult, *.dSYM, *.xcarchive
- Xcode user data: **/xcuserdata, *.xcuserstate
- OS junk: .DS_Store, __MACOSX
- Dev backups (unless --keep-dev): Dev/PBXBackups, Dev/_orphaned, Dev/*.patch, Dev/*before*, Dev/move_manifest*.txt

Options:
  --apply              Actually delete (otherwise prints what would be removed)
  --keep-dev           Keep Dev backup/archive folders and patch/before files
  --remove-vscode      Remove .vscode/
  --global-deriveddata Also remove ~/Library/Developer/Xcode/DerivedData/webOS-* (slow)
  -h, --help           Show help
EOF
}

APPLY=0
KEEP_DEV=0
REMOVE_VSCODE=0
GLOBAL_DERIVEDDATA=0

for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --keep-dev) KEEP_DEV=1 ;;
    --remove-vscode) REMOVE_VSCODE=1 ;;
    --global-deriveddata) GLOBAL_DERIVEDDATA=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $arg" >&2; usage; exit 2 ;;
  esac
done

say() { printf '%s\n' "$*"; }

rm_item() {
  local p="$1"
  [[ -e "$p" ]] || return 0
  if [[ "$APPLY" -eq 1 ]]; then
    say "[rm] $p"
    rm -rf -- "$p"
  else
    say "[dry-run] rm -rf $p"
  fi
}

rm_file() {
  local p="$1"
  [[ -f "$p" ]] || return 0
  if [[ "$APPLY" -eq 1 ]]; then
    say "[rm] $p"
    rm -f -- "$p"
  else
    say "[dry-run] rm -f $p"
  fi
}

# Guard rails: refuse to delete some non-generated paths if referenced by project/manifests.
REFERENCE_FILES=("webOS.xcodeproj/project.pbxproj")
while IFS= read -r -d '' f; do
  REFERENCE_FILES+=("$f")
done < <(find RuntimePackages -name Package.swift -print0 2>/dev/null || true)

assert_not_referenced() {
  local needle="$1"
  local f
  for f in "${REFERENCE_FILES[@]}"; do
    [[ -f "$f" ]] || continue
    if grep -n -F -- "$needle" "$f" >/dev/null 2>&1; then
      say "error: found reference to '$needle' in $f" >&2
      say "Refusing to delete; remove/adjust the reference first." >&2
      exit 1
    fi
  done
}

say "[clean_before_zip] repo: $ROOT_DIR"
if [[ "$APPLY" -eq 1 ]]; then
  say "[clean_before_zip] mode: APPLY"
else
  say "[clean_before_zip] mode: DRY-RUN"
fi

# If we’re removing Dev backups, ensure no references.
if [[ "$KEEP_DEV" -eq 0 ]]; then
  assert_not_referenced "Dev/PBXBackups"
  assert_not_referenced "Dev/_orphaned"
fi

if [[ "$REMOVE_VSCODE" -eq 1 ]]; then
  assert_not_referenced ".vscode/"
fi

# 1) Delegate to the existing fast cleaner (in-repo artifacts + caches).
if [[ -x "Dev/Tools/Scripts/clean.sh" ]]; then
  if [[ "$APPLY" -eq 1 ]]; then
    if [[ "$GLOBAL_DERIVEDDATA" -eq 1 ]]; then
      "$ROOT_DIR/Dev/Tools/Scripts/clean.sh" --global-deriveddata
    else
      "$ROOT_DIR/Dev/Tools/Scripts/clean.sh"
    fi
  else
    if [[ "$GLOBAL_DERIVEDDATA" -eq 1 ]]; then
      say "[dry-run] Dev/Tools/Scripts/clean.sh --global-deriveddata"
    else
      say "[dry-run] Dev/Tools/Scripts/clean.sh"
    fi
  fi
else
  say "warning: Dev/Tools/Scripts/clean.sh not found/executable; continuing with local cleanup" >&2
fi

# 2) Remove Xcode user data (safe).
while IFS= read -r -d '' d; do
  d="${d#./}"
  [[ "$d" == .git/* ]] && continue
  rm_item "$d"
done < <(find . -type d -name xcuserdata -not -path './.git/*' -print0 2>/dev/null || true)

while IFS= read -r -d '' f; do
  f="${f#./}"
  [[ "$f" == .git/* ]] && continue
  rm_file "$f"
done < <(find . -type f -name '*.xcuserstate' -not -path './.git/*' -print0 2>/dev/null || true)

# 3) Remove SwiftPM caches everywhere (this is the main cause of huge zips).
# Note: Using find keeps this robust even with many packages.
while IFS= read -r -d '' d; do
  d="${d#./}"
  [[ "$d" == .git/* ]] && continue
  rm_item "$d"
done < <(find . -type d \( -name '.build' -o -name '.swiftpm' \) -not -path './.git/*' -prune -print0 2>/dev/null || true)

# 3b) Remove additional build caches that may live inside SwiftPM/Xcode trees.
# These should never be shipped in a zip and should never be committed.
while IFS= read -r -d '' d; do
  d="${d#./}"
  [[ "$d" == .git/* ]] && continue
  rm_item "$d"
done < <(find . -type d \( -name 'index-build' -o -name 'ModuleCache' -o -name 'DerivedData' -o -name 'ModuleCache.noindex' \) -not -path './.git/*' -prune -print0 2>/dev/null || true)

while IFS= read -r -d '' d; do
  d="${d#./}"
  [[ "$d" == .git/* ]] && continue
  rm_item "$d"
done < <(find . -type d -name '*.xcresult' -not -path './.git/*' -prune -print0 2>/dev/null || true)

# 4) Dev backup/archive files (optional).
if [[ "$KEEP_DEV" -eq 0 ]]; then
  rm_item "Dev/PBXBackups"
  rm_item "Dev/_orphaned"

  while IFS= read -r -d '' f; do
    f="${f#./}"
    rm_file "$f"
  done < <(
    find Dev -maxdepth 1 -type f \
      \( \
        -name 'diff*.patch' -o \
        -name '*.before' -o \
        -name '*_before' -o \
        -name '*before*' -o \
        -name 'move_manifest*.txt' -o \
        -name 'assets_inventory*.json' -o \
        -name 'assets_inventory_recursive.json' -o \
        -name 'removed_binary_artifacts.txt' -o \
        -name 'reorg_move_tests.py' \
      \) \
      -print0 2>/dev/null || true
  )
fi

# 5) Optional editor config.
if [[ "$REMOVE_VSCODE" -eq 1 ]]; then
  rm_item ".vscode"
fi

say "[clean_before_zip] done"
