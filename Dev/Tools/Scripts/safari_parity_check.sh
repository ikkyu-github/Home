#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

say() { printf "%s\n" "$*"; }

say "[parity] repo: $ROOT_DIR"

# 1) Layering (delegates to existing check).
if [[ -x "Dev/Tools/Scripts/architecture_check.sh" ]]; then
  say "[parity] running architecture_check.sh (layering + imports)"
  Dev/Tools/Scripts/architecture_check.sh
else
  say "[parity] WARN: Dev/Tools/Scripts/architecture_check.sh not found/executable"
fi

# 2) WKWebView construction sites (Swift only).
# Enforce: constructors appear only in CoreKit's WebViewPool.
ALLOWLIST_FILE="RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift"

CONSTRUCTOR_PATTERN='WKWebView[[:space:]]*\(frame:'
say "[parity] scanning for WKWebView constructors in .swift files"

# Use ripgrep if available, otherwise fall back to grep.
if command -v rg >/dev/null 2>&1; then
  MATCHES=$(rg -n --type-add 'swift:*.swift' -t swift "$CONSTRUCTOR_PATTERN" \
    --glob "!$ALLOWLIST_FILE" \
    --glob "!.build/**" \
    --glob "!**/DerivedData/**" \
    RuntimePackages App 2>/dev/null || true)
else
  MATCHES=$(grep -RInE --include='*.swift' "$CONSTRUCTOR_PATTERN" RuntimePackages App \
    | grep -v "^$ALLOWLIST_FILE:" \
    || true)
fi

if [[ -n "${MATCHES}" ]]; then
  say "FAIL: Found unexpected WKWebView constructor call sites (expected only $ALLOWLIST_FILE)"
  say "$MATCHES"
  exit 2
else
  say "ok: WKWebView constructors only in $ALLOWLIST_FILE"
fi

say "[parity] done"
