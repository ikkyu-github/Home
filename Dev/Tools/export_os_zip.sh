#!/usr/bin/env bash
set -euo pipefail

# This script is intended to run as an Xcode Run Script phase.
# It exports build/OS.zip containing the built .app bundle and embedded runtime payloads.

config="${CONFIGURATION:-}"
if [[ "${EXPORT_OS_ZIP_ALWAYS:-0}" != "1" ]]; then
  if [[ -n "${config}" && "${config}" != "Release" ]]; then
    echo "[export_os_zip] Skipping export for CONFIGURATION=${config} (set EXPORT_OS_ZIP_ALWAYS=1 to override)"
    exit 0
  fi
fi

srcroot="${SRCROOT:-"$(pwd)"}"
app_path=""

if [[ -n "${TARGET_BUILD_DIR:-}" && -n "${FULL_PRODUCT_NAME:-}" ]]; then
  app_path="${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}"
fi

if [[ -z "${app_path}" || ! -d "${app_path}" ]]; then
  echo "[export_os_zip] Built app not found at: ${app_path:-<empty>}" >&2
  echo "[export_os_zip] Hint: this script expects Xcode env vars TARGET_BUILD_DIR and FULL_PRODUCT_NAME." >&2
  exit 2
fi

out_dir="${WEBOS_OSZIP_DIR:-$HOME/Library/Caches/webOS/OSZip}"
mkdir -p "${out_dir}"
zip_path="${out_dir}/OS.zip"

staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/oszip.XXXXXXXX")"
trap 'rm -rf "${staging_dir}"' EXIT

staged_app="${staging_dir}/$(basename "${app_path}")"

echo "[export_os_zip] Staging app bundle"
ditto "${app_path}" "${staged_app}"

main_info_plist="${staged_app}/Info.plist"
enabled_ids_json="[]"

if [[ -f "${main_info_plist}" ]]; then
  # Convert to JSON and extract SafariLikeEnabledPluginIDs (if present).
  enabled_ids_json="$(/usr/bin/plutil -convert json -o - "${main_info_plist}" 2>/dev/null | /usr/bin/python3 -c 'import json,sys
try:
  data=json.load(sys.stdin)
except Exception:
  print("[]"); sys.exit(0)
ids=data.get("SafariLikeEnabledPluginIDs")
if isinstance(ids,list) and all(isinstance(x,str) for x in ids):
  print(json.dumps(ids))
else:
  print("[]")
')"
fi

# Prune embedded plugin payloads that declare SafariLikePluginID but are not enabled.
# This only affects external plugin bundles/frameworks. Built-in (compiled-in) plugins are not removable.

declare -a candidate_roots=(
  "${staged_app}/PlugIns"
  "${staged_app}/Plugins"
  "${staged_app}/Frameworks"
)

python_filter='import json,sys
enabled=set(json.loads(sys.argv[1]))
plugin_id=sys.argv[2]
print("keep" if (not plugin_id) or (plugin_id in enabled) else "drop")'

for root in "${candidate_roots[@]}"; do
  [[ -d "${root}" ]] || continue

  # Bundles and frameworks can have their Info.plist in different locations.
  while IFS= read -r -d '' payload; do
    plist=""
    if [[ -d "${payload}" ]]; then
      if [[ -f "${payload}/Info.plist" ]]; then
        plist="${payload}/Info.plist"
      elif [[ -f "${payload}/Resources/Info.plist" ]]; then
        plist="${payload}/Resources/Info.plist"
      elif [[ -f "${payload}/Contents/Info.plist" ]]; then
        plist="${payload}/Contents/Info.plist"
      fi
    fi

    [[ -n "${plist}" ]] || continue

    plugin_id="$(/usr/bin/plutil -extract SafariLikePluginID raw -o - "${plist}" 2>/dev/null || true)"
    [[ -n "${plugin_id}" ]] || continue

    decision="$(/usr/bin/python3 -c "${python_filter}" "${enabled_ids_json}" "${plugin_id}")"
    if [[ "${decision}" == "drop" ]]; then
      echo "[export_os_zip] Removing disabled plugin payload (${plugin_id}): ${payload}"
      rm -rf "${payload}"
    fi
  done < <(find "${root}" -maxdepth 2 \( -name '*.bundle' -o -name '*.framework' \) -print0 2>/dev/null)

done

echo "[export_os_zip] Writing ${zip_path}"
rm -f "${zip_path}"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "${staged_app}" "${zip_path}"

# Validate size
"${srcroot}/Dev/Tools/check_os_zip_size.sh" "${zip_path}"

echo "[export_os_zip] Done: ${zip_path}"