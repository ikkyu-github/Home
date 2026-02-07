#!/usr/bin/env bash
set -euo pipefail

LOG_PATH="${1:-$HOME/Library/Logs/webOS/xcodebuild-webOS.log}"
MAX_LINES="${WEBOS_WARNINGS_MAX_LINES:-50}"

if [[ ! -f "$LOG_PATH" ]]; then
  echo "FAIL: log not found: $LOG_PATH" >&2
  exit 2
fi

warn_count=$(grep -ci "warning:" "$LOG_PATH" || true)
if [[ "$warn_count" != "0" ]]; then
  echo "FAIL: warnings detected ($warn_count)" >&2
  echo "log: $LOG_PATH" >&2
  echo "First warnings (up to $MAX_LINES):" >&2
  (grep -n -i "warning:" "$LOG_PATH" | head -n "$MAX_LINES") >&2 || true
  exit 3
fi

echo "ok: warning count = 0"
