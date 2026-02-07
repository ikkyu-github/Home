#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -d .git ]]; then
  echo "[hooks][ERROR] .git not found; are you in a git repo?" >&2
  exit 2
fi

echo "[hooks] configuring repo to use .githooks as core.hooksPath"
git config core.hooksPath .githooks

echo "[hooks] installed. Next commit will run: Scripts/repo_guard.sh"
