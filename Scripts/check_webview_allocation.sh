#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${REPO_ROOT}" ]]; then
  echo "[check_webview_allocation] ERROR: not inside a git repository" >&2
  exit 2
fi

cd "${REPO_ROOT}"

ALLOW_SUFFIX="SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift"

scan_pattern() {
  local pattern="$1"

  # Scan git-tracked content to avoid false positives from build outputs/logs
  # and to avoid filesystem errors if a tracked path is missing locally.
  # git grep exit codes:
  # - 0: matches found
  # - 1: no matches
  # - 2: error
  git grep -n --no-color --fixed-strings -- "${pattern}" \
    | awk -F: -v allow_suffix="${ALLOW_SUFFIX}" '
        function endswith(str, suffix) {
          return (length(str) >= length(suffix)) && (substr(str, length(str) - length(suffix) + 1) == suffix)
        }
        {
          file = $1
          if (!endswith(file, allow_suffix)) {
            print $0
          }
        }
      ' \
    || true
}

violations="$({
  scan_pattern "WKWebView(";
  scan_pattern "WKWebView (";
} | LC_ALL=C sort -u)"

if [[ -n "${violations}" ]]; then
  echo "[check_webview_allocation] FAIL: WKWebView constructor usage found outside allowlist" >&2
  echo "[check_webview_allocation] Allowed file suffix: ${ALLOW_SUFFIX}" >&2
  echo "---" >&2
  echo "${violations}" >&2
  exit 1
fi

echo "[check_webview_allocation] OK: no WKWebView(...) constructors outside allowlist"
