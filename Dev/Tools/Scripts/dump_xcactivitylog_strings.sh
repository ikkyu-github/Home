#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage:
  Dev/Tools/Scripts/dump_xcactivitylog_strings.sh <input.xcactivitylog> <output.txt>

Notes:
  - This is a workspace-only fallback when `xcrun xcactivitylog dump` is unavailable.
  - It decompresses the .xcactivitylog (if gzipped) and runs `strings` to extract readable text.
EOF
}

if [[ $# -ne 2 ]]; then
  usage
  exit 2
fi

INP="$1"
OUT="$2"

TMP_RAW="$(mktemp -t webos_xcactivitylog_raw.XXXXXX)"
trap 'rm -f "$TMP_RAW"' EXIT

python3 Dev/Tools/Scripts/extract_xcactivitylog_text.py "$INP" --output "$TMP_RAW"
mkdir -p "$(dirname "$OUT")"

strings -a -n 6 "$TMP_RAW" > "$OUT"

echo "wrote: $OUT"
