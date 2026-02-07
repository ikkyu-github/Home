#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# Scan only plugin-related source trees.
# Rule: plugins must not import UIKit/SwiftUI/SafariLikeUIKit directly.
PATTERN='^[[:space:]]*import[[:space:]]+(UIKit|SwiftUI|SafariLikeUIKit)\b'

scan_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0

  # Find Swift sources under any Plugins/ subtree.
  while IFS= read -r -d '' file; do
    if grep -nE "$PATTERN" "$file" >/dev/null; then
      echo "UI import found in plugin source: $file" >&2
      grep -nE "$PATTERN" "$file" >&2
      return 1
    fi
  done < <(find "$dir" -type f -name '*.swift' \( -path '*/Plugins/*' -o -path '*/Plugin*/*' \) -print0)
}

scan_dir "$ROOT_DIR/RuntimePackages"
scan_dir "$ROOT_DIR/DevPackages"

echo "OK: no UI imports found in plugin sources."
