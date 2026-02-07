#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

# xcodebuild can regenerate these in-repo user state directories.
# Keep the repo clean and avoid repo_guard failures on subsequent runs.
rm -rf \
  "$ROOT_DIR/webOS.xcodeproj/xcuserdata" \
  "$ROOT_DIR/webOS.xcodeproj/project.xcworkspace/xcuserdata" || true

"$ROOT_DIR/Scripts/repo_guard.sh"

PROJECT_PATH="$ROOT_DIR/webOS.xcodeproj"
SCHEME="${WEBOS_XCODE_SCHEME:-webOS}"
DESTINATION="${WEBOS_XCODE_DESTINATION:-generic/platform=iOS Simulator}"
DERIVED_DATA_PATH="${WEBOS_DERIVED_DATA_PATH:-$HOME/Library/Caches/webOS/XcodeDerivedData}"
LOG_DIR="${WEBOS_XCODE_LOG_DIR:-$HOME/Library/Logs/webOS}"

TAIL_LINES=80
PRINT_LOG_PATH=0
FAIL_ON_WARNINGS=0

usage() {
  cat <<'EOF'
Usage:
  Dev/Tools/Scripts/xcodebuild.sh [--tail N] [--print-log-path] [--fail-on-warnings] [xcodebuild args...]

Runs xcodebuild with DerivedData redirected OUTSIDE the repo, and writes logs OUTSIDE the repo.

Defaults:
  -project webOS.xcodeproj
  -scheme  webOS
  -destination 'generic/platform=iOS Simulator'
  -derivedDataPath ~/Library/Caches/webOS/XcodeDerivedData
  --tail 80

Examples:
  Dev/Tools/Scripts/xcodebuild.sh --tail 20 build
  Dev/Tools/Scripts/xcodebuild.sh --fail-on-warnings clean build
  Dev/Tools/Scripts/xcodebuild.sh -list
  Dev/Tools/Scripts/xcodebuild.sh --print-log-path
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --tail)
      TAIL_LINES="${2:-}";
      shift 2
      ;;
    --print-log-path)
      PRINT_LOG_PATH=1
      shift 1
      ;;
    --fail-on-warnings)
      FAIL_ON_WARNINGS=1
      shift 1
      ;;
    *)
      break
      ;;
  esac
done

mkdir -p "$DERIVED_DATA_PATH" "$LOG_DIR"

echo "[xcodebuild] repo: $ROOT_DIR"
echo "[xcodebuild] derivedDataPath: $DERIVED_DATA_PATH"

# Only inject defaults when the caller did not provide explicit overrides.
ARGS=("$@")
HAS_PROJECT_OR_WORKSPACE=0
HAS_SCHEME=0
HAS_DESTINATION=0
HAS_DERIVED_DATA=0
SCHEME_FOR_LOG="$SCHEME"

for ((i=0; i<${#ARGS[@]}; i++)); do
  case "${ARGS[$i]}" in
    -project|-workspace)
      HAS_PROJECT_OR_WORKSPACE=1
      ;;
    -scheme)
      HAS_SCHEME=1
      if [[ $((i+1)) -lt ${#ARGS[@]} ]]; then
        SCHEME_FOR_LOG="${ARGS[$((i+1))]}"
      fi
      ;;
    -destination)
      HAS_DESTINATION=1
      ;;
    -derivedDataPath)
      HAS_DERIVED_DATA=1
      ;;
  esac
done

LOG_PATH="$LOG_DIR/xcodebuild-${SCHEME_FOR_LOG}.log"
echo "[xcodebuild] log: $LOG_PATH"

CMD=(xcodebuild)
if [[ "$HAS_PROJECT_OR_WORKSPACE" -eq 0 ]]; then
  CMD+=( -project "$PROJECT_PATH" )
fi
if [[ "$HAS_SCHEME" -eq 0 ]]; then
  CMD+=( -scheme "$SCHEME" )
fi
if [[ "$HAS_DESTINATION" -eq 0 ]]; then
  CMD+=( -destination "$DESTINATION" )
fi
if [[ "$HAS_DERIVED_DATA" -eq 0 ]]; then
  CMD+=( -derivedDataPath "$DERIVED_DATA_PATH" )
fi
CMD+=("${ARGS[@]}")

STATUS=0
set +e
"${CMD[@]}" >"$LOG_PATH" 2>&1
STATUS=$?
set -e

rm -rf \
  "$ROOT_DIR/webOS.xcodeproj/xcuserdata" \
  "$ROOT_DIR/webOS.xcodeproj/project.xcworkspace/xcuserdata" || true

if [[ "$PRINT_LOG_PATH" -eq 1 ]]; then
  echo "$LOG_PATH"
fi

if [[ "${TAIL_LINES}" != "0" ]]; then
  tail -n "$TAIL_LINES" "$LOG_PATH" || true
fi

if [[ "$STATUS" -eq 0 && "$FAIL_ON_WARNINGS" -eq 1 ]]; then
  WARN_COUNT=$(grep -ci "warning:" "$LOG_PATH" || true)
  if [[ "$WARN_COUNT" != "0" ]]; then
    echo "FAIL: warnings detected in xcodebuild output ($WARN_COUNT)" >&2
    echo "First warnings (up to 50):" >&2
    (grep -n -i "warning:" "$LOG_PATH" | head -n 50) >&2 || true
    exit 2
  fi
fi

exit "$STATUS"
