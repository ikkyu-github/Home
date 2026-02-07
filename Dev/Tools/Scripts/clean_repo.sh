#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${ROOT}" || ! -d "${ROOT}" ]]; then
  echo "error: must run inside a git repo" >&2
  exit 2
fi

cd "${ROOT}"

echo "[clean_repo] root: ${ROOT}"

remove_dir_if_exists() {
  local path="$1"
  if [[ -d "${path}" ]]; then
    echo "[clean_repo] rm -rf ${path}" >&2
    rm -rf "${path}"
  fi
}

# 1) Delete build logs (repo junk)
remove_dir_if_exists "${ROOT}/build_logs"

# 2) Delete SwiftPM artifacts under RuntimePackages/*/.build
if [[ -d "${ROOT}/RuntimePackages" ]]; then
  while IFS= read -r -d '' dir; do
    echo "[clean_repo] rm -rf ${dir}" >&2
    rm -rf "${dir}"
  done < <(find "${ROOT}/RuntimePackages" -name '.build' -type d -prune -print0)
fi

# 3) Delete macOS zip junk directories
while IFS= read -r -d '' dir; do
  echo "[clean_repo] rm -rf ${dir}" >&2
  rm -rf "${dir}"
done < <(find "${ROOT}" -name '__MACOSX' -type d -prune -print0)

# 4) Delete .DS_Store everywhere
if find "${ROOT}" -name '.DS_Store' -type f -print -quit | grep -q .; then
  echo "[clean_repo] deleting .DS_Store files" >&2
  find "${ROOT}" -name '.DS_Store' -type f -delete
fi

# 5) Delete Xcode per-user workspace data
while IFS= read -r -d '' dir; do
  echo "[clean_repo] rm -rf ${dir}" >&2
  rm -rf "${dir}"
done < <(find "${ROOT}" -name 'xcuserdata' -type d -prune -print0)

echo "[clean_repo] done"
