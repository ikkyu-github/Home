#!/usr/bin/env bash
set -euo pipefail

# prezip_check.sh
# Fails if common build/cache bloat is present in the working tree.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail=0

check_dir() {
  local p="$1"
  if [[ -d "$p" ]]; then
    echo "FOUND_DIR $p"
    fail=1
  fi
}

check_glob_dirs() {
  local pattern="$1"
  shopt -s nullglob
  local matches=( $pattern )
  shopt -u nullglob
  if [[ ${#matches[@]} -gt 0 ]]; then
    local m
    for m in "${matches[@]}"; do
      echo "FOUND_DIR $m"
    done
    fail=1
  fi
}

check_file_glob() {
  local pattern="$1"
  shopt -s nullglob
  local matches=( $pattern )
  shopt -u nullglob
  if [[ ${#matches[@]} -gt 0 ]]; then
    local m
    for m in "${matches[@]}"; do
      echo "FOUND_FILE $m"
    done
    fail=1
  fi
}

check_find_files() {
  local name="$1"
  # Print up to a reasonable number of hits; any hit is a failure.
  local hits
  hits="$(find . -type f -name "$name" -not -path './.git/*' 2>/dev/null | head -n 200)"
  if [[ -n "$hits" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      echo "FOUND_FILE ${line#./}"
    done <<< "$hits"
    fail=1
  fi
}

# Top-level common offenders
check_dir "build"
check_dir "DerivedData"
check_dir ".build"
check_dir ".swiftpm"
check_dir "ModuleCache"
check_dir "ModuleCache.noindex"

# Recursive SwiftPM caches
check_glob_dirs "RuntimePackages/*/.build"
check_glob_dirs "RuntimePackages/*/.swiftpm"

# Xcode outputs
check_find_files "*.xcresult"
check_find_files "*.xcarchive"
check_find_files "*.dSYM"
check_find_files "*.dSYM.zip"

if [[ "$fail" -ne 0 ]]; then
  echo ""
  echo "prezip_check: FAIL (build/cache artifacts detected)"
  echo "Suggested: ./Dev/Tools/clean_before_zip.sh --apply"
  exit 1
fi

echo "prezip_check: OK"
