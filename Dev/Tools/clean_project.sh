#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage:
  ./clean_project.sh [--apply] [--keep-dev-archives] [--remove-vscode]
                    [--remove-gpx] [--global-deriveddata]

Default is DRY-RUN (prints what would be removed).

What it removes (when enabled):
- Build artifacts/caches: build/, **/.build, **/.swiftpm, DerivedData/, ModuleCache*, __MACOSX
- Xcode user data: **/xcuserdata, *.xcuserstate
- OS junk: .DS_Store
- Dev archives (optional): Dev/PBXBackups, Dev/_orphaned, Dev/*.patch, Dev/*_before, Dev/*before*, Dev/move_manifest*.txt, Dev/assets_inventory*.json
- Optional: .vscode/ (editor-only)
- Optional: *.gpx at repo root (dev-only location traces)

Safety:
- Never removes .git/
- Verifies candidate deletions are NOT referenced by Xcode targets (project.pbxproj) or SwiftPM manifests (RuntimePackages/**/Package.swift), except known-generated outputs.

Flags:
  --apply             Actually delete (otherwise dry-run).
  --keep-dev-archives Do NOT delete Dev archive/backups.
  --remove-vscode     Remove .vscode/.
  --remove-gpx        Remove top-level *.gpx files.
  --global-deriveddata Also remove ~/Library/Developer/Xcode/DerivedData/webOS-* (delegates to Dev/Tools/Scripts/clean.sh).
  -h, --help          Show this help.
EOF
}

APPLY=0
KEEP_DEV_ARCHIVES=0
REMOVE_VSCODE=0
REMOVE_GPX=0
GLOBAL_DERIVEDDATA=0

for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --keep-dev-archives) KEEP_DEV_ARCHIVES=1 ;;
    --remove-vscode) REMOVE_VSCODE=1 ;;
    --remove-gpx) REMOVE_GPX=1 ;;
    --global-deriveddata) GLOBAL_DERIVEDDATA=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $arg"; usage; exit 2 ;;
  esac
done

say() { printf '%s\n' "$*"; }

rm_item() {
  local p="$1"
  if [[ ! -e "$p" ]]; then
    return 0
  fi
  if [[ "$APPLY" -eq 1 ]]; then
    say "[rm] $p"
    rm -rf -- "$p"
  else
    say "[dry-run] rm -rf $p"
  fi
}

rm_file() {
  local p="$1"
  if [[ ! -f "$p" ]]; then
    return 0
  fi
  if [[ "$APPLY" -eq 1 ]]; then
    say "[rm] $p"
    rm -f -- "$p"
  else
    say "[dry-run] rm -f $p"
  fi
}

# Reference guard: only block deletions that would break targets/manifests.
# Note: build/OS.zip is an output path in the Xcode project; it's safe to delete.
REFERENCE_FILES=(
  "webOS.xcodeproj/project.pbxproj"
)
while IFS= read -r -d '' f; do
  REFERENCE_FILES+=("$f")
done < <(find RuntimePackages -name Package.swift -print0 2>/dev/null || true)

assert_not_referenced() {
  local needle="$1"
  local f
  for f in "${REFERENCE_FILES[@]}"; do
    [[ -f "$f" ]] || continue
    if grep -n -F -- "$needle" "$f" >/dev/null 2>&1; then
      say "error: found reference to '$needle' in $f"
      say "Refusing to delete; remove/adjust the reference first."
      exit 1
    fi
  done
}

say "[clean_project] repo: $ROOT_DIR"
if [[ "$APPLY" -eq 1 ]]; then
  say "[clean_project] mode: APPLY (deleting)"
else
  say "[clean_project] mode: DRY-RUN (no deletion)"
fi

# 1) Guard rails for non-generated candidate paths.
if [[ "$KEEP_DEV_ARCHIVES" -eq 0 ]]; then
  assert_not_referenced "Dev/PBXBackups"
  assert_not_referenced "Dev/_orphaned"
  assert_not_referenced "Dev/project.pbxproj"
fi
if [[ "$REMOVE_VSCODE" -eq 1 ]]; then
  assert_not_referenced ".vscode/"
fi
if [[ "$REMOVE_GPX" -eq 1 ]]; then
  # These should never be referenced by targets; still guard for completeness.
  while IFS= read -r -d '' gpx; do
    assert_not_referenced "${gpx#./}"
  done < <(find . -maxdepth 1 -name '*.gpx' -print0 2>/dev/null || true)
fi

# 2) General build/caches cleanup (rebuildable).
# Reuse existing repo cleanup script.
if [[ -x "Dev/Tools/Scripts/clean.sh" ]]; then
  if [[ "$APPLY" -eq 1 ]]; then
    if [[ "$GLOBAL_DERIVEDDATA" -eq 1 ]]; then
      "${ROOT_DIR}/Dev/Tools/Scripts/clean.sh" --global-deriveddata
    else
      "${ROOT_DIR}/Dev/Tools/Scripts/clean.sh"
    fi
  else
    if [[ "$GLOBAL_DERIVEDDATA" -eq 1 ]]; then
      say "[dry-run] Dev/Tools/Scripts/clean.sh --global-deriveddata"
    else
      say "[dry-run] Dev/Tools/Scripts/clean.sh"
    fi
  fi
fi

# 3) Extra Xcode user data (often accidentally created).
# These are not build products but should not ship.
while IFS= read -r -d '' d; do
  d="${d#./}"
  [[ -z "$d" ]] && continue
  [[ "$d" == .git/* ]] && continue
  rm_item "$d"
done < <(find . -type d -name xcuserdata -not -path './.git/*' -print0 2>/dev/null || true)

while IFS= read -r -d '' f; do
  f="${f#./}"
  [[ -z "$f" ]] && continue
  [[ "$f" == .git/* ]] && continue
  rm_file "$f"
done < <(find . -type f -name '*.xcuserstate' -not -path './.git/*' -print0 2>/dev/null || true)

# 4) Explicit top-level caches/outputs.
rm_item "build"
rm_item "DerivedData"
rm_item ".swiftpm"
rm_item ".build"

# 5) SwiftPM per-package build caches.
for d in RuntimePackages/*/.build RuntimePackages/*/.swiftpm; do
  rm_item "$d"
done

# 6) Dev archives/backups (optional).
if [[ "$KEEP_DEV_ARCHIVES" -eq 0 ]]; then
  rm_item "Dev/PBXBackups"
  rm_item "Dev/_orphaned"

  while IFS= read -r -d '' f; do
    f="${f#./}"
    [[ -z "$f" ]] && continue
    rm_file "$f"
  done < <(
    find Dev -maxdepth 1 -type f \
      \( \
        -name 'diff*.patch' -o \
        -name '*.before' -o \
        -name '*_before' -o \
        -name 'move_manifest*.txt' -o \
        -name 'assets_inventory*.json' -o \
        -name 'removed_binary_artifacts.txt' -o \
        -name 'reorg_move_tests.py' \
      \) \
      -print0 2>/dev/null || true
  )
fi

# 7) Optional editor config.
if [[ "$REMOVE_VSCODE" -eq 1 ]]; then
  rm_item ".vscode"
fi

# 8) Optional dev-only GPX traces at repo root.
if [[ "$REMOVE_GPX" -eq 1 ]]; then
  for f in ./*.gpx; do
    rm_file "$f"
  done
fi

# 9) OS junk (in case it exists).
while IFS= read -r -d '' f; do
  f="${f#./}"
  [[ -z "$f" ]] && continue
  [[ "$f" == .git/* ]] && continue
  rm_file "$f"
done < <(find . -type f -name '.DS_Store' -not -path './.git/*' -print0 2>/dev/null || true)

say "[clean_project] done"
