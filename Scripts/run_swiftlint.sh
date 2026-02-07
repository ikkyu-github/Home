#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "error: SwiftLint not installed"
  echo "install: brew install swiftlint"
  exit 127
fi

CONFIG_FILE="$ROOT_DIR/.swiftlint.yml"

swiftlint lint --config "$CONFIG_FILE" "$@"
