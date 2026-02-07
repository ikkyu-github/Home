#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

DERIVED_DATA_PATH="${WEBOS_DERIVED_DATA_PATH:-$HOME/Library/Caches/webOS/XcodeDerivedData}"
LOG_DIR="${WEBOS_XCODE_LOG_DIR:-$HOME/Library/Logs/webOS}"
DESTINATION="${WEBOS_XCODE_DESTINATION:-generic/platform=iOS Simulator}"
CONFIGURATION="${WEBOS_XCODE_CONFIGURATION:-Debug}"

SCHEMES=(webOS SafariLikeKit SafariLikeCoreKit BrowserCore)
TAIL_LINES=120
COPY_LOGS_TO_WORKSPACE_DIR=""

usage() {
  cat <<'EOF'
Usage:
  Dev/Tools/Scripts/diagnose_build.sh [options]

Options:
  --schemes "A,B,C"     Comma-separated scheme list (default: webOS,SafariLikeKit,SafariLikeCoreKit,BrowserCore)
  --configuration NAME   Debug/Release (default: Debug)
  --destination SPEC     xcodebuild destination (default: generic/platform=iOS Simulator)
  --tail N               Tail N lines per scheme log on failure (default: 120)
  --no-clean             Skip cleaning repo artifacts + external DerivedData
  --copy-logs-to-workspace DIR
                          Copies per-scheme logs into a workspace directory (e.g. Dev/IncomingLogs).
                          This is OFF by default to keep the repo thin.

What it does (deterministic, no in-repo artifacts):
  1) Asserts repo has no in-tree artifacts
  2) Cleans repo artifacts + deletes external DerivedData (unless --no-clean)
  3) Resolves Swift package dependencies
  4) Builds each scheme and summarizes any 'Missing package product' errors from logs
  5) Re-asserts repo remains clean
EOF
}

DO_CLEAN=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --schemes)
      IFS=',' read -r -a SCHEMES <<< "${2:-}"
      shift 2
      ;;
    --configuration)
      CONFIGURATION="${2:-}"
      shift 2
      ;;
    --destination)
      DESTINATION="${2:-}"
      shift 2
      ;;
    --tail)
      TAIL_LINES="${2:-120}"
      shift 2
      ;;
    --no-clean)
      DO_CLEAN=0
      shift 1
      ;;
    --copy-logs-to-workspace)
      COPY_LOGS_TO_WORKSPACE_DIR="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

mkdir -p "$LOG_DIR"

echo "== webOS diagnose build =="
echo "repo: $ROOT_DIR"
echo "derivedDataPath: $DERIVED_DATA_PATH"
echo "logDir: $LOG_DIR"
echo "destination: $DESTINATION"
echo "configuration: $CONFIGURATION"
echo "schemes: ${SCHEMES[*]}"

echo "== assert (pre) =="
Dev/Tools/Scripts/assert_no_bloat.sh

echo "== assert SwiftPM linkage =="
python3 Dev/Tools/Scripts/assert_spm_linkage.py

if [[ "$DO_CLEAN" -eq 1 ]]; then
  echo "== clean repo artifacts =="
  Dev/Tools/Scripts/clean.sh >/dev/null

  echo "== remove external DerivedData =="
  rm -rf "$DERIVED_DATA_PATH" || true
fi

echo "== resolve packages =="
Dev/Tools/Scripts/xcodebuild.sh --tail 60 \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resolvePackageDependencies

FAILED=0
for scheme in "${SCHEMES[@]}"; do
  echo "== build: $scheme =="
  set +e
  Dev/Tools/Scripts/xcodebuild.sh --tail 40 \
    -scheme "$scheme" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build
  STATUS=$?
  set -e

  LOG_PATH="$LOG_DIR/xcodebuild-${scheme}.log"

  if [[ "$STATUS" -ne 0 ]]; then
    FAILED=1
    echo "!! FAILED: $scheme (exit $STATUS)"
    if [[ -f "$LOG_PATH" ]]; then
      echo "-- Missing package product (grep) --"
      grep -nE "Missing package product" "$LOG_PATH" || true
      echo "-- Errors (tail grep) --"
      grep -nE "\berror:|\bfatal error:|\bld:|\bUndefined symbols" "$LOG_PATH" | tail -n "$TAIL_LINES" || true
      echo "-- Raw log tail --"
      tail -n "$TAIL_LINES" "$LOG_PATH" || true
    else
      echo "(no log at $LOG_PATH)"
    fi
  fi
done

echo "== assert (post) =="
Dev/Tools/Scripts/assert_no_bloat.sh

echo "== logs =="
for scheme in "${SCHEMES[@]}"; do
  echo "$LOG_DIR/xcodebuild-${scheme}.log"
done

if [[ -n "$COPY_LOGS_TO_WORKSPACE_DIR" ]]; then
  DEST_DIR="$ROOT_DIR/$COPY_LOGS_TO_WORKSPACE_DIR"
  mkdir -p "$DEST_DIR"
  TS="$(date +%Y%m%d-%H%M%S)"
  echo "== copy logs into workspace =="
  echo "dest: $DEST_DIR"
  for scheme in "${SCHEMES[@]}"; do
    SRC="$LOG_DIR/xcodebuild-${scheme}.log"
    if [[ -f "$SRC" ]]; then
      cp -f "$SRC" "$DEST_DIR/xcodebuild-${scheme}-$TS.log"
      echo "copied: $DEST_DIR/xcodebuild-${scheme}-$TS.log"
    fi
  done
fi

if [[ "$FAILED" -ne 0 ]]; then
  exit 1
fi

echo "OK: all schemes built"
