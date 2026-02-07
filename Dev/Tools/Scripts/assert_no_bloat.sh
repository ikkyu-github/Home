#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

echo "[assert] repo: $ROOT_DIR"

# 1) Any SwiftPM .build directories anywhere in the repo are forbidden.
if find . -type d -name .build -not -path './.git/*' -print -quit | grep -q .; then
  echo "[assert][ERROR] Found one or more '.build/' directories in the repo. Run: Dev/Tools/Scripts/clean.sh" >&2
  find . -type d -name .build -not -path './.git/*' -print >&2
  exit 1
fi

# 2) Root build/ directory is forbidden.
if [[ -d "$ROOT_DIR/build" ]]; then
  echo "[assert][ERROR] Found repo root 'build/' directory. Run: Dev/Tools/Scripts/clean.sh" >&2
  echo "$ROOT_DIR/build" >&2
  exit 1
fi

# 3) Root build_logs/ directory is forbidden.
if [[ -d "$ROOT_DIR/build_logs" ]]; then
  echo "[assert][ERROR] Found repo root 'build_logs/' directory. Move logs outside the repo." >&2
  echo "$ROOT_DIR/build_logs" >&2
  exit 1
fi

# 4) Root .venv/ directory is forbidden.
if [[ -d "$ROOT_DIR/.venv" ]]; then
  echo "[assert][ERROR] Found repo root '.venv/' directory. Virtualenvs must live outside the repo." >&2
  echo "$ROOT_DIR/.venv" >&2
  exit 1
fi

# 5) macOS Finder metadata is forbidden.
if find . -type f -name .DS_Store -not -path './.git/*' -print -quit | grep -q .; then
  echo "[assert][ERROR] Found one or more '.DS_Store' files in the repo." >&2
  find . -type f -name .DS_Store -not -path './.git/*' -print >&2
  exit 1
fi

# 6) Export zips must be written outside the repo.
if find . -maxdepth 1 -type f -name 'webOS-clean-*.zip' -print -quit | grep -q .; then
  echo "[assert][ERROR] Found in-repo export zip(s) 'webOS-clean-*.zip'. Export output must be outside the repo." >&2
  ls -1 "$ROOT_DIR"/webOS-clean-*.zip 2>/dev/null >&2 || true
  exit 1
fi

echo "[assert] OK: no forbidden build artifacts present"
