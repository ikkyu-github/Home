#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage:
  Dev/Tools/Scripts/clean.sh

Deletes build artifacts only (safe; does not remove source):
- SwiftPM: deletes every `.build/` directory anywhere under the repo
- Xcode: deletes repo-root `build/`
- Xcode logs: deletes repo-root `build_logs/`
- Python venv: deletes repo-root `.venv/`
- macOS: deletes `.DS_Store` files
- Xcode DerivedData: deletes `~/Library/Developer/Xcode/DerivedData/webOS-*`

Notes:
- This script refuses to delete anything outside expected locations.
EOF
}

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $arg"; usage; exit 2 ;;
  esac
done

echo "[clean] repo: $ROOT_DIR"

remove_dir_best_effort() {
  local dir="$1"
  local attempt=1
  local max_attempts=6

  while [[ -e "$dir" && $attempt -le $max_attempts ]]; do
    rm -rf "$dir" 2>/dev/null || true
    [[ ! -e "$dir" ]] && return 0
    sleep 0.15
    attempt=$((attempt + 1))
  done

  if [[ -e "$dir" ]]; then
    echo "[clean][WARN] could not fully remove (busy?): $dir" >&2
    return 1
  fi

  return 0
}

echo "[clean] removing SwiftPM .build directories..."
BUILD_DIRS=()
while IFS= read -r dir; do
  BUILD_DIRS+=("$dir")
done < <(
  find . -type d -name .build \
    -not -path './.git/*' \
    -prune \
    -print \
  | sort
)

if (( ${#BUILD_DIRS[@]} == 0 )); then
  echo "[clean] SwiftPM .build directories: (none)"
else
  printf '%s\n' "${BUILD_DIRS[@]}"
  for dir in "${BUILD_DIRS[@]}"; do
    remove_dir_best_effort "$dir" || true
  done
fi

if [[ -d "$ROOT_DIR/build" ]]; then
  echo "[clean] removing repo build/: $ROOT_DIR/build"
  rm -rf "$ROOT_DIR/build"
else
  echo "[clean] repo build/: (none)"
fi

if [[ -d "$ROOT_DIR/build_logs" ]]; then
  echo "[clean] removing repo build_logs/: $ROOT_DIR/build_logs"
  rm -rf "$ROOT_DIR/build_logs"
else
  echo "[clean] repo build_logs/: (none)"
fi

if [[ -d "$ROOT_DIR/.venv" ]]; then
  echo "[clean] removing repo .venv/: $ROOT_DIR/.venv"
  rm -rf "$ROOT_DIR/.venv"
else
  echo "[clean] repo .venv/: (none)"
fi

echo "[clean] removing .DS_Store files..."
find . -type f -name .DS_Store -not -path './.git/*' -print -delete || true

echo "[clean] removing Xcode xcuserdata directories (forbidden in repo)..."
XCODE_USERDATA_DIRS=()
while IFS= read -r dir; do
  XCODE_USERDATA_DIRS+=("$dir")
done < <(
  find . -type d -name xcuserdata \
    -not -path './.git/*' \
    -prune \
    -print \
  | sort
)

if (( ${#XCODE_USERDATA_DIRS[@]} == 0 )); then
  echo "[clean] xcuserdata: (none)"
else
  printf '%s\n' "${XCODE_USERDATA_DIRS[@]}"
  for dir in "${XCODE_USERDATA_DIRS[@]}"; do
    remove_dir_best_effort "$dir" || true
  done
fi

DD="$HOME/Library/Developer/Xcode/DerivedData"
if [[ -d "$DD" ]]; then
  echo "[clean] removing Xcode DerivedData (scoped): $DD/webOS-*"
  # Best-effort: DerivedData can be mutated concurrently by Xcode.
  # Do not fail the repo cleanup if a directory is busy/non-empty.
  rm -rf "$DD"/webOS-* || true
else
  echo "[clean] Xcode DerivedData: (missing)"
fi

echo "[clean] done"