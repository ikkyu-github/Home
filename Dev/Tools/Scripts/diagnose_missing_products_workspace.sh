#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

IN_DIR="${1:-Dev/IncomingLogs}"
IN_DIR="$ROOT_DIR/$IN_DIR"

if [[ ! -d "$IN_DIR" ]]; then
  echo "ERROR: No workspace log dir: $IN_DIR" >&2
  echo "Create it and drop failing logs there, e.g.:" >&2
  echo "  mkdir -p Dev/IncomingLogs" >&2
  echo "  cp ~/Library/Logs/webOS/xcodebuild-*.log Dev/IncomingLogs/" >&2
  exit 2
fi

LOGS=("$IN_DIR"/*.log)
if [[ ${#LOGS[@]} -eq 1 && "${LOGS[0]}" == "$IN_DIR/*.log" ]]; then
  echo "ERROR: No .log files found in $IN_DIR" >&2
  echo "Expected something like: Dev/IncomingLogs/xcodebuild-webOS-YYYYMMDD-HHMMSS.log" >&2
  exit 2
fi

echo "== workspace missing-product diagnosis =="
echo "repo: $ROOT_DIR"
echo "logs: $IN_DIR"

# 1) pbxproj: verify package/product + per-target deps (evidence from workspace file)
echo "\n== pbxproj audit =="
python3 Dev/Tools/Scripts/xcode_spm_audit.py --targets BrowserCore SafariLikeKit SafariLikeCoreKit webOS

# 2) scan source imports (evidence from workspace file)
echo "\n== import scan =="
python3 - <<'PY'
import re
from pathlib import Path
root = Path('.').resolve()
mods = ['Collections','Logging']
rx = re.compile(r'^\s*import\s+(\w+)\b', re.MULTILINE)
found = {m: [] for m in mods}
for p in root.rglob('*.swift'):
    if any(part in {'.git', '.build', 'DerivedData'} for part in p.parts):
        continue
    try:
        t = p.read_text(encoding='utf-8', errors='replace')
    except Exception:
        continue
    imps = set(m for m in rx.findall(t) if m in found)
    for m in imps:
        found[m].append(p.relative_to(root))
for m in mods:
    files = found[m]
    if not files:
        print(f"- import {m}: (none)")
    else:
        print(f"- import {m}:")
        for f in sorted(files):
            print(f"  - {f}")
PY

# 3) parse workspace logs for missing-package-product errors

echo "\n== log parse =="
python3 Dev/Tools/Scripts/parse_xcode_missing_package_products.py --repo-root "$ROOT_DIR" "${LOGS[@]}"
