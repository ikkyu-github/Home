#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v zip >/dev/null 2>&1; then
  echo "[export][ERROR] 'zip' is not installed" >&2
  exit 1
fi

OUT_DIR="${WEBOS_EXPORT_DIR:-$HOME/Library/Caches/webOS/Exports}"
TS="$(date +%Y%m%d-%H%M%S)"
ZIP_NAME="webOS-clean-${TS}.zip"
ZIP_PATH="$OUT_DIR/$ZIP_NAME"

mkdir -p "$OUT_DIR"

# Refuse to write exports inside the repo.
python3 - <<'PY' "$ROOT_DIR" "$ZIP_PATH"
import os
import sys
root = os.path.realpath(sys.argv[1])
zip_path = os.path.realpath(sys.argv[2])
if zip_path.startswith(root + os.sep):
    raise SystemExit(f"[export][ERROR] Refusing to write export inside the repo: {zip_path}")
PY

echo "[export] repo: $ROOT_DIR"
echo "[export] output: $ZIP_PATH"

repo_size_bytes() {
  python3 - <<'PY'
import os
from pathlib import Path
root = Path('.')
size = 0
for dirpath, dirnames, filenames in os.walk(root):
  dirnames[:] = [d for d in dirnames if d != '.git']
  for fn in filenames:
    p = Path(dirpath) / fn
    if p.is_symlink():
      continue
    try:
      size += p.stat().st_size
    except FileNotFoundError:
      pass
print(size)
PY
}

human_bytes() {
  python3 - <<'PY' "$1"
import sys
n = int(sys.argv[1])
units = ['B','KiB','MiB','GiB','TiB']
v = float(n)
i = 0
while v >= 1024 and i < len(units) - 1:
  v /= 1024
  i += 1
print(f"{int(v)} {units[i]}" if i == 0 else f"{v:.2f} {units[i]}")
PY
}

BEFORE_BYTES="$(repo_size_bytes)"

# Enforce hygiene before export (and remove any local artifacts).
"$ROOT_DIR/Scripts/repo_guard.sh"
"$ROOT_DIR/Dev/Tools/Scripts/clean.sh"
"$ROOT_DIR/Scripts/repo_guard.sh"

AFTER_BYTES="$(repo_size_bytes)"

# Defense-in-depth explicit excludes.
EXCLUDE_GLOBS=(
  ".git/*" "*/.git/*"
  ".build/*" "*/.build/*"
  "build/*" "*/build/*"
  "DerivedData/*" "*/DerivedData/*"
  "xcuserdata/*" "*/xcuserdata/*"
  ".swiftpm/*" "*/.swiftpm/*"
  "build_logs/*" "*/build_logs/*"
  "IncomingLogs/*" "*/IncomingLogs/*"
  "__MACOSX/*" "*/__MACOSX/*"
  "*.xcresult*"
  ".DS_Store" "*/.DS_Store"
  "*.pcm" "*.swiftmodule" "*.swiftdeps" "*.dia" "*.d" "*.timestamp"
)

rm -f "$ZIP_PATH"

echo "[export] selection: find (source filetypes)"

LIST_FILE="$(mktemp -t webos-export-list.XXXXXX)"
trap 'rm -f "$LIST_FILE"' EXIT

find . \
  -type d \( -name .git -o -name .build -o -name build -o -name DerivedData -o -name build_logs -o -name IncomingLogs -o -name xcuserdata -o -name .swiftpm -o -name __MACOSX \) -prune -o \
  -type f \( \
    -name '*.swift' -o -name '*.m' -o -name '*.mm' -o -name '*.h' -o -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.hpp' -o -name '*.metal' -o \
    -name '*.plist' -o -name '*.entitlements' -o -name '*.xcconfig' -o \
    -name '*.md' -o -name '*.json' -o -name '*.yaml' -o -name '*.yml' -o -name '*.txt' -o -name '*.gpx' -o \
    -name '*.sh' -o -name '*.py' -o -name 'Package.swift' -o -name 'Package.resolved' \
  \) -print | sed 's|^\./||' >"$LIST_FILE"

zip -q -X "$ZIP_PATH" -@ -x "${EXCLUDE_GLOBS[@]}" <"$LIST_FILE"

# Validate that the zip does not contain forbidden entries.
python3 - <<'PY' "$ZIP_PATH"
import sys
import zipfile

zip_path = sys.argv[1]
forbidden_parts = (
    '/.git/', '/.build/', '/build/', '/DerivedData/', '/build_logs/', '/IncomingLogs/', '/xcuserdata/', '/.swiftpm/', '/__MACOSX/',
)
forbidden_suffixes = (
    '.DS_Store', '.pcm', '.swiftmodule', '.swiftdeps', '.dia', '.d', '.timestamp', '.xcresult'
)

bad = []
with zipfile.ZipFile(zip_path, 'r') as z:
    for name in z.namelist():
        n = '/' + name.lstrip('/')
        if any(p in n for p in forbidden_parts):
            bad.append(name)
            continue
        if name.endswith(forbidden_suffixes):
            bad.append(name)

if bad:
    print('[export][ERROR] Zip validation failed: forbidden entries found', file=sys.stderr)
    for x in bad[:50]:
        print('  -', x, file=sys.stderr)
    if len(bad) > 50:
        print(f'  ... and {len(bad)-50} more', file=sys.stderr)
    sys.exit(3)

print('[export] zip validated: no forbidden artifacts present')
PY

ZIP_BYTES="$(python3 - <<PY
import os
print(os.path.getsize(r"$ZIP_PATH"))
PY
)"

ZIP_COUNT="$(python3 - <<PY
import zipfile
with zipfile.ZipFile(r"$ZIP_PATH") as z:
  print(len([n for n in z.namelist() if not n.endswith('/')]))
PY
)"

echo "[export] repo size before: $(human_bytes "$BEFORE_BYTES")"
echo "[export] repo size after:  $(human_bytes "$AFTER_BYTES")"
echo "[export] zip size:        $(human_bytes "$ZIP_BYTES")"
echo "[export] zip file count:  $ZIP_COUNT"
echo "[export] done: $ZIP_PATH"
