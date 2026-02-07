#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

PROJECT_PATH="${WEBOS_XCODE_PROJECT_PATH:-$ROOT_DIR/webOS.xcodeproj}"
SCHEME="${WEBOS_XCODE_SCHEME:-webOS}"
DESTINATION="${WEBOS_XCODE_DESTINATION:-generic/platform=iOS Simulator}"

usage() {
  cat <<'EOF'
Usage:
  Dev/Tools/Scripts/resolve_packages_in_active_deriveddata.sh [options]

Options:
  --deriveddata DIR   Use this DerivedData directory (default: newest ~/Library/Developer/Xcode/DerivedData/webOS-*)
  --scheme NAME       Xcode scheme (default: webOS)
  --destination SPEC  xcodebuild destination (default: generic/platform=iOS Simulator)

What it does:
  - Runs `xcodebuild -resolvePackageDependencies` into the DerivedData folder that Xcode GUI is currently using.
  - Verifies that package checkouts exist afterward.

Why:
  - The failure signature "Missing package product 'Logging'/'Collections'" with location "Package Loading"
    usually means the DerivedData being used has no resolved SourcePackages yet.
EOF
}

DERIVED_DATA=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --deriveddata)
      DERIVED_DATA="${2:-}"
      shift 2
      ;;
    --scheme)
      SCHEME="${2:-}"
      shift 2
      ;;
    --destination)
      DESTINATION="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$DERIVED_DATA" ]]; then
  DERIVED_DATA="$(ls -1dt "$HOME/Library/Developer/Xcode/DerivedData/webOS-"* 2>/dev/null | head -n 1 || true)"
fi

if [[ -z "$DERIVED_DATA" || ! -d "$DERIVED_DATA" ]]; then
  echo "ERROR: could not find a DerivedData folder matching ~/Library/Developer/Xcode/DerivedData/webOS-*" >&2
  echo "Pass one explicitly via --deriveddata <DIR>." >&2
  exit 2
fi

echo "== resolve packages into active DerivedData =="
echo "project: $PROJECT_PATH"
echo "scheme: $SCHEME"
echo "destination: $DESTINATION"
echo "derivedDataPath: $DERIVED_DATA"

set -o pipefail
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  -resolvePackageDependencies \
  | tail -n 60

CHECKOUTS="$DERIVED_DATA/SourcePackages/checkouts"
if [[ ! -d "$CHECKOUTS" ]]; then
  echo "ERROR: expected checkouts dir missing: $CHECKOUTS" >&2
  exit 1
fi

echo "== checkouts =="
ls -1 "$CHECKOUTS" | sort

if ! ls "$CHECKOUTS" | grep -qi "swift-log"; then
  echo "WARN: swift-log checkout not found under $CHECKOUTS" >&2
fi
if ! ls "$CHECKOUTS" | grep -qi "swift-collections"; then
  echo "WARN: swift-collections checkout not found under $CHECKOUTS" >&2
fi

echo "OK: packages resolved in $DERIVED_DATA"
