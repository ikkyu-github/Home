#!/usr/bin/env bash
set -euo pipefail

zip_path="${1:-}"
if [[ -z "${zip_path}" ]]; then
  echo "Usage: $0 /path/to/OS.zip" >&2
  exit 2
fi
if [[ ! -f "${zip_path}" ]]; then
  echo "Zip not found: ${zip_path}" >&2
  exit 2
fi

# macOS stat
zip_bytes="$(stat -f%z "${zip_path}")"

max_bytes="${OS_ZIP_MAX_BYTES:-}"
if [[ -z "${max_bytes}" ]]; then
  max_mb="${OS_ZIP_MAX_MB:-200}"
  if ! [[ "${max_mb}" =~ ^[0-9]+$ ]]; then
    echo "Invalid OS_ZIP_MAX_MB: ${max_mb} (expected integer)" >&2
    exit 2
  fi
  max_bytes=$(( max_mb * 1024 * 1024 ))
fi

if ! [[ "${max_bytes}" =~ ^[0-9]+$ ]]; then
  echo "Invalid OS_ZIP_MAX_BYTES: ${max_bytes} (expected integer)" >&2
  exit 2
fi

if (( zip_bytes > max_bytes )); then
  echo "OS.zip too large: ${zip_bytes} bytes > ${max_bytes} bytes" >&2
  exit 1
fi

echo "OS.zip size OK: ${zip_bytes} bytes (limit ${max_bytes})"