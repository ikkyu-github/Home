#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${REPO_ROOT}" ]]; then
  echo "[check_import_boundaries] ERROR: not inside a git repository" >&2
  exit 2
fi

cd "${REPO_ROOT}"

# Rules for /App
FORBIDDEN_IMPORTS=(
  "import WebKit"
  "import SafariLikeCoreKit"
  "import BrowserCore"
  "import SafariLikeUXKit"
)

violations=""
for pat in "${FORBIDDEN_IMPORTS[@]}"; do
  # Scan only git-tracked content under App/.
  # git grep exit codes: 0=matches, 1=no matches, 2=error
  matches="$(git grep -n --no-color --fixed-strings -- "${pat}" -- App 2>/dev/null || true)"
  if [[ -n "${matches}" ]]; then
    violations+="${matches}"$'\n'
  fi
done

# De-dup + stable output
violations="$(printf "%s" "${violations}" | LC_ALL=C sort -u)"

if [[ -n "${violations}" ]]; then
  echo "[check_import_boundaries] FAIL: forbidden imports detected under App/" >&2
  echo "---" >&2
  echo "${violations}" >&2
  exit 1
fi

echo "[check_import_boundaries] OK: App/ import boundaries clean"
