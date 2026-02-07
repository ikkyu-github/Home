#!/usr/bin/env bash
set -euo pipefail

# Fails the build if any two Swift source files within a source root share the same basename.
# This prevents Xcode build failures like: "duplicate output file <Name>.stringsdata".
#
# Usage:
#   forbid_duplicate_basenames.sh <sources-root>

sources_root="${1:-}"

if [[ -z "${sources_root}" ]]; then
  echo "Usage: $0 <sources-root>" >&2
  exit 2
fi

if [[ ! -d "${sources_root}" ]]; then
  echo "forbid_duplicate_basenames: not a directory: ${sources_root}" >&2
  exit 2
fi

# Collect basenames of all Swift sources.
# (We intentionally treat basenames as the collision domain because Swift's localized strings
#  extraction outputs are based on the source filename.)
if ! find "${sources_root}" -type f -name '*.swift' -print -quit | grep -q .; then
  exit 0
fi

duplicates="$({
  find "${sources_root}" -type f -name '*.swift' -print0 \
    | xargs -0 -n1 basename \
    | LC_ALL=C sort \
    | LC_ALL=C uniq -d
} || true)"

if [[ -n "${duplicates}" ]]; then
  echo "Duplicate Swift basenames detected under: ${sources_root}" >&2
  echo "These will break Xcode due to duplicate outputs (e.g. *.stringsdata)." >&2
  while IFS= read -r name; do
    [[ -z "${name}" ]] && continue
    echo " - ${name}" >&2
  done <<< "${duplicates}"
  exit 1
fi
