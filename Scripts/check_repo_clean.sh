#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Directories that must never exist in the repo (generated/build artifacts)
FORBIDDEN_DIR_NAMES=(
  ".build"
  "build"
  "DerivedData"
  "__MACOSX"
)

# Generated file extensions that must never be committed
FORBIDDEN_FILE_GLOBS=(
  "*.pcm"
  "*.swiftmodule"
  "*.swiftdeps"
  "*.dia"
  "*.d"
  "*.timestamp"
)

# Exclusions: never scan nested VCS metadata
FIND_EXCLUDES=(
  -path "./.git" -o -path "./.git/*"
)

found_any=0

echo "[check] repo: $ROOT_DIR"

echo "[check] forbidden directories:"
for name in "${FORBIDDEN_DIR_NAMES[@]}"; do
  # -prune keeps this fast even if a build directory is huge.
  matches=$(find . \( "${FIND_EXCLUDES[@]}" \) -prune -o -type d -name "$name" -prune -print | sed 's|^\./||' || true)
  if [[ -n "$matches" ]]; then
    found_any=1
    echo "$matches" | sed 's|^|  - |'
  fi
done

echo "[check] forbidden generated files:"
for glob in "${FORBIDDEN_FILE_GLOBS[@]}"; do
  matches=$(find . \( "${FIND_EXCLUDES[@]}" \) -prune -o -type f -name "$glob" -print | sed 's|^\./||' || true)
  if [[ -n "$matches" ]]; then
    found_any=1
    echo "$matches" | sed 's|^|  - |'
  fi
done

if [[ "$found_any" -ne 0 ]]; then
  echo ""
  echo "FAIL: repo contains forbidden build artifacts/generated files"
  echo "Hint: run Dev/Tools/Scripts/clean_repo.sh and re-check."
  exit 2
fi

echo "ok: repo looks clean"
