#!/usr/bin/env bash
set -euo pipefail

ROOT="${SRCROOT:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"}"

# Walk upward until we find the repo root markers.
if [[ ! -d "$ROOT/RuntimePackages" ]]; then
  probe="$ROOT"
  while [[ "$probe" != "/" && ! -d "$probe/RuntimePackages" ]]; do
    probe="$(cd "$probe/.." && pwd)"
  done
  if [[ -d "$probe/RuntimePackages" ]]; then
    ROOT="$probe"
  fi
fi

fail=0

banner() {
  printf "\n== %s ==\n" "$1"
}

report_matches() {
  local title="$1"
  local matches="$2"

  banner "$title"
  printf "%s\n" "$matches"
}

check_no_swiftui_in_browsercore() {
  local dir="$ROOT/RuntimePackages/BrowserCore/Sources/BrowserCore"
  if [[ ! -d "$dir" ]]; then
    echo "warning: BrowserCore sources not found at: $dir" >&2
    return 0
  fi

  local matches
  matches="$(grep -RIn --include='*.swift' -E '^[[:space:]]*(@_implementationOnly[[:space:]]+)?import[[:space:]]+SwiftUI\b' "$dir" || true)"

  if [[ -n "$matches" ]]; then
    report_matches "ERROR: BrowserCore must not import SwiftUI" "$matches"
    fail=1
  fi
}

check_no_browsercore_imports_in_swiftui_sources() {
  local dir="$1"
  local label="$2"

  if [[ ! -d "$dir" ]]; then
    return 0
  fi

  local swiftui_files
  swiftui_files="$(grep -RIl --include='*.swift' -E '^[[:space:]]*import[[:space:]]+SwiftUI\b' "$dir" || true)"

  if [[ -z "$swiftui_files" ]]; then
    return 0
  fi

  local bad_matches=""
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    local file_matches
    file_matches="$(grep -nE '^[[:space:]]*(@_implementationOnly[[:space:]]+)?import[[:space:]]+BrowserCore\b' "$file" || true)"
    if [[ -n "$file_matches" ]]; then
      bad_matches+="$file:$file_matches"$'\n'
    fi
  done <<< "$swiftui_files"

  if [[ -n "$bad_matches" ]]; then
    report_matches "ERROR: SwiftUI ($label) must not import BrowserCore (use SafariLikeCoreKit re-exports instead)" "$bad_matches"
    fail=1
  fi
}

check_no_swiftui_in_browsercore

# Treat any SwiftUI-importing source in SafariLikeKit as UI.
check_no_browsercore_imports_in_swiftui_sources "$ROOT/RuntimePackages/SafariLikeKit/Sources/SafariLikeKit" "SafariLikeKit"
check_no_browsercore_imports_in_swiftui_sources "$ROOT/App" "App"

if [[ "$fail" -ne 0 ]]; then
  echo "\nModule boundary assertions failed." >&2
  exit 1
fi

echo "Module boundary assertions passed."
