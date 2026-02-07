#!/bin/bash
set -euo pipefail

FORBIDDEN=(
  "__MACOSX"
  "xcuserdata"
  ".DS_Store"
  "*.xcuserstate"
)

found_any=0
for pattern in "${FORBIDDEN[@]}"; do
  matches=$(find . -name "$pattern" -not -path './.git/*' -print | grep -v '^$' || true)
  if [[ -n "$matches" ]]; then
    echo "[forbidden_files_check] ERROR: Found forbidden files or directories matching '$pattern':"
    echo "$matches"
    found_any=1
  fi
done

if [[ $found_any -eq 1 ]]; then
  echo "[forbidden_files_check] FAIL: Forbidden files present. Please clean the repo."
  exit 1
else
  echo "[forbidden_files_check] OK: No forbidden files found."
fi
