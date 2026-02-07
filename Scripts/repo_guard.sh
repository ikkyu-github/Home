#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "[repo-guard] repo: $ROOT_DIR"

# Source-only size budget (excludes .git). This is a regression detector: if the repo size
# suddenly jumps, it almost always means build artifacts or large binaries snuck in.
# Override locally/CI if needed via WEBOS_MAX_REPO_SIZE_MIB.
MAX_REPO_SIZE_MIB="${WEBOS_MAX_REPO_SIZE_MIB:-15}"
if ! [[ "$MAX_REPO_SIZE_MIB" =~ ^[0-9]+$ ]]; then
  echo "[repo-guard][ERROR] WEBOS_MAX_REPO_SIZE_MIB must be an integer MiB value (got '$MAX_REPO_SIZE_MIB')." >&2
  exit 2
fi
MAX_REPO_SIZE_BYTES=$((MAX_REPO_SIZE_MIB * 1024 * 1024))

repo_size_bytes() {
  python3 - <<'PY'
import os
from pathlib import Path

root = Path('.')
size = 0
for dirpath, dirnames, filenames in os.walk(root):
  dirnames[:] = [d for d in dirnames if d != '.git']
  for fn in filenames:
    p = Path(dirpath) / fn
    if p.is_symlink():
      continue
    try:
      size += p.stat().st_size
    except FileNotFoundError:
      pass
print(size)
PY
}

print_top_10_largest_paths() {
  echo "[repo-guard] Top 10 largest paths (approx):" >&2

  # Include dot-directories/files (e.g. .github, .vscode) but avoid '.' and '..'.
  shopt -s nullglob
  local items=( * .[!.]* ..?* )

  local filtered=()
  local p
  for p in "${items[@]}"; do
    [[ "$p" == ".git" ]] && continue
    filtered+=("$p")
  done

  if [[ ${#filtered[@]} -eq 0 ]]; then
    echo "  (no paths found)" >&2
    return 0
  fi

  du -sk -- "${filtered[@]}" 2>/dev/null \
    | sort -nr \
    | head -n 10 \
    | awk '{ kib=$1; $1=""; sub(/^\t|^ /,"",$0); printf "  - %.2f MiB  %s\n", kib/1024, $0 }' \
    >&2 || true
}

"$ROOT_DIR/Dev/Tools/Scripts/validate_swift_packages.sh"
"$ROOT_DIR/Dev/Tools/Scripts/validate_xcode_swift_packages.sh"

# Forbidden directories anywhere in the repo.
# Includes (at minimum): .build, build, DerivedData
FORBIDDEN_DIR_NAMES=(
  ".build"
  "build"
  "DerivedData"
  "xcuserdata"
  ".swiftpm"
  "build_logs"
  "IncomingLogs"
)

# Forbidden generated file types anywhere in the repo.
# Includes (at minimum): *.pcm, *.swiftmodule, *.swiftdeps, *.dia, *.d, *.timestamp
FORBIDDEN_FILE_GLOBS=(
  "*.pcm"
  "*.swiftmodule"
  "*.swiftdeps"
  "*.dia"
  "*.d"
  "*.timestamp"
  "*.xcactivitylog*"
  "*.xcresult"
  "*.xcresult/*"
  ".DS_Store"
)

# Never scan nested VCS metadata.
FIND_EXCLUDES=( -path "./.git" -o -path "./.git/*" )

fail_dir() {
  local name="$1"
  if find . \( "${FIND_EXCLUDES[@]}" \) -prune -o -type d -name "$name" -print -quit | grep -q .; then
    echo "[repo-guard][ERROR] Forbidden directory '$name' exists in the repo." >&2
    echo "[repo-guard][ERROR] This repo must not contain build/cache outputs. Delete it and rebuild; it will regenerate." >&2
    find . \( "${FIND_EXCLUDES[@]}" \) -prune -o -type d -name "$name" -print | sed 's|^\./||' >&2
    exit 1
  fi
}

fail_files() {
  local glob="$1"
  if find . \( "${FIND_EXCLUDES[@]}" \) -prune -o -type f -name "$glob" -print -quit | grep -q .; then
    echo "[repo-guard][ERROR] Forbidden generated file(s) matching '$glob' exist in the repo." >&2
    echo "[repo-guard][ERROR] These are build/index artifacts and must never be committed." >&2
    find . \( "${FIND_EXCLUDES[@]}" \) -prune -o -type f -name "$glob" -print | sed 's|^\./||' >&2
    exit 1
  fi
}

for name in "${FORBIDDEN_DIR_NAMES[@]}"; do
  fail_dir "$name"
done

for glob in "${FORBIDDEN_FILE_GLOBS[@]}"; do
  fail_files "$glob"
done

REPO_SIZE_BYTES="$(repo_size_bytes)"
if (( REPO_SIZE_BYTES > MAX_REPO_SIZE_BYTES )); then
  repo_size_mib="$(( (REPO_SIZE_BYTES + 1024*1024 - 1) / (1024*1024) ))"
  echo "[repo-guard][ERROR] Repo size regression: ~${repo_size_mib} MiB exceeds budget of ${MAX_REPO_SIZE_MIB} MiB (source-only, excludes .git)." >&2
  echo "[repo-guard][ERROR] This usually indicates generated outputs or large binaries were added. Remove them, update .gitignore if needed, and re-run." >&2
  print_top_10_largest_paths
  exit 1
fi

echo "[repo-guard] OK: no forbidden build artifacts present"
echo "[repo-guard] OK: repo size within budget (${MAX_REPO_SIZE_MIB} MiB)"

# ------------------------------
# Anti-bloat guardrails
# ------------------------------

# Per-file budgets (override via env vars in CI/local).
# These are regression detectors: budgets are intentionally set just above current
# values so we can ratchet them down over time without breaking existing builds.
#
# NOTE: We key primarily off LOC to keep the checks explainable.
WEBOS_BUDGET_TABMANAGER_MAX_LINES="${WEBOS_BUDGET_TABMANAGER_MAX_LINES:-900}"
WEBOS_BUDGET_TABMANAGER_MAX_BYTES="${WEBOS_BUDGET_TABMANAGER_MAX_BYTES:-250000}"

# TabManager controllers must remain small and single-purpose.
WEBOS_BUDGET_TABMANAGER_CONTROLLER_MAX_LINES="${WEBOS_BUDGET_TABMANAGER_CONTROLLER_MAX_LINES:-200}"
WEBOS_BUDGET_TABMANAGER_CONTROLLER_MAX_BYTES="${WEBOS_BUDGET_TABMANAGER_CONTROLLER_MAX_BYTES:-120000}"

WEBOS_BUDGET_SPLITBROWSER_VM_MAX_LINES="${WEBOS_BUDGET_SPLITBROWSER_VM_MAX_LINES:-1200}"
WEBOS_BUDGET_SPLITBROWSER_VM_MAX_BYTES="${WEBOS_BUDGET_SPLITBROWSER_VM_MAX_BYTES:-350000}"

WEBOS_BUDGET_PLUGINHOST_MAX_LINES="${WEBOS_BUDGET_PLUGINHOST_MAX_LINES:-1200}"
WEBOS_BUDGET_PLUGINHOST_MAX_BYTES="${WEBOS_BUDGET_PLUGINHOST_MAX_BYTES:-250000}"

WEBOS_BUDGET_WEBVIEW_MAX_LINES="${WEBOS_BUDGET_WEBVIEW_MAX_LINES:-1050}"
WEBOS_BUDGET_WEBVIEW_MAX_BYTES="${WEBOS_BUDGET_WEBVIEW_MAX_BYTES:-350000}"

# WebKit boundary enforcement (override via env vars in CI/local).
WEBOS_ENFORCE_WKWEBVIEW_FACTORY="${WEBOS_ENFORCE_WKWEBVIEW_FACTORY:-1}"

# Singleton regression guard (SafariLikeKit): new `static let shared` must be justified.
WEBOS_ENFORCE_SINGLETON_REGRESSION_GUARD="${WEBOS_ENFORCE_SINGLETON_REGRESSION_GUARD:-1}"

# Duplicate-content detector (Swift only). This catches copy/paste bloat without
# requiring a full static-analysis toolchain.
WEBOS_FAIL_ON_DUPLICATE_SWIFT_CONTENT="${WEBOS_FAIL_ON_DUPLICATE_SWIFT_CONTENT:-1}"
WEBOS_FAIL_ON_DUPLICATE_UTILITY_FILENAMES="${WEBOS_FAIL_ON_DUPLICATE_UTILITY_FILENAMES:-1}"
WEBOS_FAIL_ON_DUPLICATE_RISKY_UTILITY_FILENAMES="${WEBOS_FAIL_ON_DUPLICATE_RISKY_UTILITY_FILENAMES:-1}"
WEBOS_FAIL_ON_DUPLICATE_UTILITY_SYMBOLS="${WEBOS_FAIL_ON_DUPLICATE_UTILITY_SYMBOLS:-0}"

assert_int() {
  local name="$1"
  local value="$2"
  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "[repo-guard][ERROR] $name must be an integer (got '$value')." >&2
    exit 2
  fi
}

git_added_line_matches() {
  # Usage: git_added_line_matches <path> <added-line-regex>
  # Prints: path:line:content (for added lines matching regex).
  local path="$1"
  local added_regex="$2"

  command -v git >/dev/null 2>&1 || return 0
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  local diff_range=""
  if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    local base_ref="origin/${GITHUB_BASE_REF}"
    if git rev-parse --verify "$base_ref" >/dev/null 2>&1; then
      diff_range="$base_ref...HEAD"
    fi
  fi
  if [[ -z "$diff_range" ]]; then
    if git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
      diff_range="HEAD~1..HEAD"
    fi
  fi
  [[ -z "$diff_range" ]] && return 0

  git diff --unified=0 $diff_range -- "$path" \
    | awk -v re="$added_regex" '
        BEGIN { file=""; ln=0 }
        /^\+\+\+ b\// { file=substr($0,7); next }
        /^@@/ {
          if (match($0, /\+[0-9]+/)) { ln = substr($0, RSTART+1, RLENGTH-1) }
          next
        }
        /^\+/ {
          if ($0 ~ /^\+\+\+/) next
          if (file != "") {
            line = substr($0, 2)
            if (line ~ re) { printf "%s:%d:%s\n", file, ln, line }
            ln++
          }
          next
        }
      ' \
    || true
}

check_new_safarilikekit_shared_singletons() {
  # Enforce: any *new* `static let shared` inside SafariLikeKit must carry a safety header comment
  # explaining process-wide safety, and must not capture scene/tab/window identifiers.
  local root_dir="RuntimePackages/SafariLikeKit/Sources/SafariLikeKit"
  [[ -d "$root_dir" ]] || return 0

  local added
  added="$(git_added_line_matches "$root_dir" '^[[:space:]]*static[[:space:]]+let[[:space:]]+shared\\b')"
  [[ -z "$added" ]] && return 0

  local did_fail=0

  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    local file line
    file="${hit%%:*}"
    line="${hit#*:}"; line="${line%%:*}"

    if [[ ! -f "$file" ]]; then
      continue
    fi

    # Use Python to inspect the enclosing type block around the shared singleton.
    local py
    py="$(
      python3 - "$file" "$line" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
shared_line_1 = int(sys.argv[2])
lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
idx = max(0, min(shared_line_1 - 1, len(lines) - 1))

decl_re = re.compile(r"^\s*(public|internal|fileprivate|private)?\s*(final\s+)?(class|struct|enum|actor)\s+([A-Za-z_][A-Za-z0-9_]*)\b")

# Find the nearest enclosing type declaration above the shared line.
start = None
type_name = None
for i in range(idx, -1, -1):
    m = decl_re.match(lines[i])
    if m:
        start = i
        type_name = m.group(4)
        break

if start is None:
    print("ERROR no-enclosing-type")
    sys.exit(0)

# Find opening brace for that type.
open_i = None
brace_balance = 0
found_open = False
for i in range(start, len(lines)):
    s = lines[i]
    if not found_open:
        if "{" in s:
            found_open = True
            open_i = i
    if found_open:
        brace_balance += s.count("{")
        brace_balance -= s.count("}")
        if brace_balance == 0:
            end = i
            break
else:
    end = len(lines) - 1

block = lines[start : end + 1]

# Safety comment must be within the 12 lines above the shared line (within the type block).
local_shared_idx = idx - start
comment_window = block[max(0, local_shared_idx - 12) : local_shared_idx]
comment_text = "\n".join(comment_window)
has_safety = re.search(r"(?i)(SAFE\s+SINGLETON|SINGLETON\s*-\s*SAFE)", comment_text) is not None

# Unsafe identifier capture check: within the enclosing type, forbid scene/tab/window identifiers.
unsafe_re = re.compile(r"\b(sceneID|tabID|windowID)\b")

def strip_strings(s: str) -> str:
    # crude: remove simple quoted strings to avoid false positives in log messages
    return re.sub(r'"[^"\\]*(?:\\.[^"\\]*)*"', '""', s)

unsafe_hits = []
for offset, raw in enumerate(block, start=start + 1):
    s = raw.strip()
    if s.startswith("//"):
        continue
    s = strip_strings(raw)
    m = unsafe_re.search(s)
    if m:
        unsafe_hits.append((offset, m.group(1), raw.strip()))

print(f"TYPE {type_name}")
print(f"SAFETY {1 if has_safety else 0}")
for ln, tok, raw in unsafe_hits[:5]:
    print(f"UNSAFE {ln} {tok} {raw}")
PY
    )"

    if [[ "$py" == ERROR* ]]; then
      echo "[repo-guard][ERROR] Singleton guard: unable to determine enclosing type for: $file:$line" >&2
      did_fail=1
      continue
    fi

    local type_name safety
    type_name="$(printf "%s\n" "$py" | awk '/^TYPE /{print $2; exit}')"
    safety="$(printf "%s\n" "$py" | awk '/^SAFETY /{print $2; exit}')"

    if [[ "$safety" != "1" ]]; then
      echo "[repo-guard][ERROR] Singleton regression (SafariLikeKit): $file:$line introduces 'static let shared' without a safety header comment." >&2
      echo "[repo-guard][ERROR] Layer: SafariLikeKit (UI/facade)" >&2
      echo "[repo-guard][ERROR] Fix: add a header comment immediately above it explaining why it is process-wide safe." >&2
      echo "[repo-guard][ERROR] Required marker: 'SAFE SINGLETON:' (or 'SINGLETON-SAFE:')" >&2
      echo "[repo-guard][ERROR] Docs: ARCHITECTURE.md + singleton_inventory.md" >&2
      did_fail=1
    fi

    local unsafe
    unsafe="$(printf "%s\n" "$py" | awk '/^UNSAFE /{print; exit}')"
    if [[ -n "$unsafe" ]]; then
      echo "[repo-guard][ERROR] Unsafe singleton detected: $file:$line (type ${type_name}) references scene/tab/window identity." >&2
      echo "[repo-guard][ERROR] $unsafe" >&2
      echo "[repo-guard][ERROR] Fix: do not store per-scene/per-tab/per-window state in a process-wide singleton. Move it into SceneRuntimeContext/TabManager/WindowSession." >&2
      did_fail=1
    fi
  done <<< "$added"

  if [[ "$did_fail" -ne 0 ]]; then
    exit 1
  fi
}

check_file_budget() {
  local rel_path="$1"
  local max_lines="$2"
  local max_bytes="$3"
  local guidance="$4"

  assert_int "${rel_path}:max_lines" "$max_lines"
  assert_int "${rel_path}:max_bytes" "$max_bytes"

  if [[ ! -f "$rel_path" ]]; then
    echo "[repo-guard] note: budget target missing (skipping): $rel_path" >&2
    return 0
  fi

  local lines bytes
  lines="$(wc -l < "$rel_path" | tr -d ' ')"
  bytes="$(wc -c < "$rel_path" | tr -d ' ')"

  if (( lines > max_lines || bytes > max_bytes )); then
    echo "[repo-guard][ERROR] File budget exceeded: $rel_path" >&2
    echo "[repo-guard][ERROR]  current lines: $lines" >&2
    echo "[repo-guard][ERROR]  allowed lines: $max_lines" >&2
    echo "[repo-guard][ERROR]  current bytes: $bytes" >&2
    echo "[repo-guard][ERROR]  allowed bytes: $max_bytes" >&2
    echo "[repo-guard][ERROR] Guidance: $guidance" >&2
    echo "[repo-guard][ERROR] Architecture docs: ARCHITECTURE.md + Docs/ARCHITECTURE_GUARDRAILS.md" >&2
    echo "[repo-guard][ERROR] Adjust budgets via env vars (see WEBOS_BUDGET_* in Scripts/repo_guard.sh)." >&2
    exit 1
  fi
}

check_dir_budget_each_file() {
  local rel_dir="$1"
  local max_lines="$2"
  local max_bytes="$3"
  local guidance="$4"

  assert_int "${rel_dir}:max_lines" "$max_lines"
  assert_int "${rel_dir}:max_bytes" "$max_bytes"

  if [[ ! -d "$rel_dir" ]]; then
    echo "[repo-guard] note: budget target missing (skipping): $rel_dir" >&2
    return 0
  fi

  local did_fail=0
  local file
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    local lines bytes
    lines="$(wc -l < "$file" | tr -d ' ')"
    bytes="$(wc -c < "$file" | tr -d ' ')"
    if (( lines > max_lines || bytes > max_bytes )); then
      echo "[repo-guard][ERROR] Controller budget exceeded: $file" >&2
      echo "[repo-guard][ERROR]  current lines: $lines" >&2
      echo "[repo-guard][ERROR]  allowed lines: $max_lines" >&2
      echo "[repo-guard][ERROR]  current bytes: $bytes" >&2
      echo "[repo-guard][ERROR]  allowed bytes: $max_bytes" >&2
      echo "[repo-guard][ERROR] Guidance: $guidance" >&2
      did_fail=1
    fi
  done < <(find "$rel_dir" -maxdepth 1 -type f -name '*.swift' -print | sed 's|^\./||')

  if [[ "$did_fail" -ne 0 ]]; then
    echo "[repo-guard][ERROR] Architecture docs: ARCHITECTURE.md + Docs/ARCHITECTURE_GUARDRAILS.md" >&2
    exit 1
  fi
}

check_duplicate_swift_content() {
  local root="RuntimePackages"
  if [[ ! -d "$root" ]]; then
    return 0
  fi

  # Uses shasum + awk to find identical file contents.
  # Excludes .git via find root restriction.
  local duplicates
  duplicates="$(
    find "$root" -type f -name '*.swift' -print0 \
      | xargs -0 shasum -a 256 \
      | awk '
          { h=$1; $1=""; sub(/^ +/,"",$0); paths[h]=paths[h]"\n  - " $0; count[h]++ }
          END { for (h in count) if (count[h] > 1) { print "hash: " h paths[h] "\n" } }
        '
  )"

  if [[ -n "$duplicates" ]]; then
    echo "[repo-guard][ERROR] Duplicate Swift source content detected (copy/paste bloat):" >&2
    echo "$duplicates" >&2
    echo "[repo-guard][ERROR] Guidance: extract shared logic to a single utility/type, or delete redundant files." >&2
    if [[ "$WEBOS_FAIL_ON_DUPLICATE_SWIFT_CONTENT" == "1" ]]; then
      exit 1
    else
      echo "[repo-guard] note: WEBOS_FAIL_ON_DUPLICATE_SWIFT_CONTENT=0 so this is non-fatal" >&2
    fi
  fi
}

check_duplicate_utility_filenames() {
  local root="RuntimePackages"
  if [[ ! -d "$root" ]]; then
    return 0
  fi

  # Heuristic: generic utility filenames tend to accrete duplicated grab-bag code.
  # Keep this pattern list short and high-signal.
  local pattern='(Utils|Utilities|Helpers|Extensions|Common|Shared)\.swift$'

  local matches
  matches="$(find "$root" -type f -name '*.swift' -path '*/Sources/*' -print | awk -F/ -v pat="$pattern" '
    $NF ~ pat { print $NF ":" $0 }
  ' | sort)"

  [[ -z "$matches" ]] && return 0

  local dups
  dups="$(printf "%s\n" "$matches" | awk -F: '{print $1}' | sort | uniq -c | awk '$1>1 {print $2 " (x" $1 ")"}')"

  [[ -z "$dups" ]] && return 0

  echo "[repo-guard][ERROR] Duplicate generic utility filenames detected:" >&2
  echo "$dups" | sed 's/^/  - /' >&2
  echo "[repo-guard][ERROR] Matches:" >&2
  printf "%s\n" "$matches" | sed 's/^/  /' >&2
  echo "[repo-guard][ERROR] Guidance: consolidate into a single module-scoped file, or rename to a domain-specific filename." >&2
  if [[ "$WEBOS_FAIL_ON_DUPLICATE_UTILITY_FILENAMES" == "1" ]]; then
    exit 1
  else
    echo "[repo-guard] note: WEBOS_FAIL_ON_DUPLICATE_UTILITY_FILENAMES=0 so this is non-fatal" >&2
  fi
}

check_duplicate_risky_utility_basenames() {
  local root="RuntimePackages"
  [[ -d "$root" ]] || return 0

  local names=("TabUtils.swift" "WebUtils.swift" "BrowserHelpers.swift")
  local any_fail=0

  local name
  for name in "${names[@]}"; do
    local matches
    matches="$(find "$root" -type f -name "$name" -print | sed 's|^\./||' | sort || true)"
    [[ -z "$matches" ]] && continue

    local count
    count="$(printf "%s\n" "$matches" | grep -c . || true)"
    if (( count > 1 )); then
      echo "[repo-guard][ERROR] Duplicate utility filename detected: $name" >&2
      echo "[repo-guard][ERROR] occurrences: $count" >&2
      echo "[repo-guard][ERROR] paths:" >&2
      printf "%s\n" "$matches" | sed 's/^/  - /' >&2
      echo "[repo-guard][ERROR] Guidance: duplicate utility detected. Consolidate into the existing module/file (single source of truth)." >&2
      any_fail=1
    fi
  done

  if [[ "$any_fail" -ne 0 ]]; then
    if [[ "$WEBOS_FAIL_ON_DUPLICATE_RISKY_UTILITY_FILENAMES" == "1" ]]; then
      exit 1
    else
      echo "[repo-guard] note: WEBOS_FAIL_ON_DUPLICATE_RISKY_UTILITY_FILENAMES=0 so this is non-fatal" >&2
    fi
  fi
}

check_duplicate_utility_type_names() {
  # Cheap heuristic: repeated utility-type names (e.g. FooUtils, BarHelpers) across multiple
  # files are a strong signal of copy/paste bloat.
  local root="RuntimePackages"
  [[ -d "$root" ]] || return 0

  local matches
  matches="$(
    grep -RIn --include='*.swift' -E '^[[:space:]]*(public|internal|fileprivate|private)?[[:space:]]*(final[[:space:]]+)?(class|struct|enum|protocol|actor|extension)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)(Utils|Helpers)\b' \
      "$root" 2>/dev/null \
      | sed 's|^\./||'
  )" || true

  [[ -z "$matches" ]] && return 0

  # Summarize duplicates by symbol name across different files.
  local dups
  dups="$(
    printf "%s\n" "$matches" \
      | awk -F: '{file=$1":"$2; line=$0; name=$0; sub(/.*\b(class|struct|enum|protocol|actor|extension)[[:space:]]+/,"",name); sub(/[^A-Za-z0-9_].*$/, "", name); print name "\t" file "\t" line }' \
      | awk -F'\t' '{count[$1]++; lines[$1]=lines[$1]"\n  - " $3} END { for (n in count) if (count[n] > 1) print n " (x" count[n] ")" lines[n] "\n" }'
  )" || true

  [[ -z "$dups" ]] && return 0

  echo "[repo-guard][ERROR] Repeated utility-type names detected (heuristic):" >&2
  echo "$dups" >&2
  echo "[repo-guard][ERROR] Guidance: consolidate utility logic into one type/file; avoid parallel *Utils/*Helpers variants." >&2
  if [[ "$WEBOS_FAIL_ON_DUPLICATE_UTILITY_SYMBOLS" == "1" ]]; then
    exit 1
  else
    echo "[repo-guard] note: WEBOS_FAIL_ON_DUPLICATE_UTILITY_SYMBOLS=0 so this is non-fatal" >&2
  fi
}

check_wkwebview_constructors() {
  # Enforces the architectural rule: WKWebView must be constructed only via WebViewPool.
  # This is intentionally a simple grep-based check (no Swift parsing).
  local allowed_file="RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift"
  local allowed_regex
  allowed_regex="$(printf "%s" "$allowed_file" | sed -e 's/[\\.^$|?*+()\[\]{}]/\\&/g')"

  if [[ ! -f "$allowed_file" ]]; then
    echo "[repo-guard][ERROR] WKWebView factory guard: allowed file missing: $allowed_file" >&2
    exit 2
  fi

  local matches violations
  matches="$(
    grep -RIn --include='*.swift' -E 'WKWebView([[:space:]]*\(|[[:space:]]*\.init[[:space:]]*\()' RuntimePackages App 2>/dev/null \
      | sed 's|^\./||'
  )" || true

  [[ -z "$matches" ]] && return 0

  violations="$(
    printf "%s\n" "$matches" \
      | grep -v -E "^${allowed_regex}:"
  )" || true

  if [[ -n "$violations" ]]; then
    echo "[repo-guard][ERROR] WKWebView must be created via WebViewPool.makeWebView(configuration:)." >&2
    echo "[repo-guard][ERROR] Offending WKWebView constructors (file:line):" >&2
    echo "$violations" | sed 's/^/  /' >&2
    echo "[repo-guard][ERROR] Fix: replace WKWebView(...) with WebViewPool.makeWebView(configuration:) and plumb the handle through." >&2
    echo "[repo-guard][ERROR] Docs: ARCHITECTURE.md + Docs/WKWebKit_Boundary_Inventory.md" >&2
    exit 1
  fi
}

echo "[repo-guard] Checking file budgets..."
check_file_budget \
  "RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/TabManager.swift" \
  "$WEBOS_BUDGET_TABMANAGER_MAX_LINES" \
  "$WEBOS_BUDGET_TABMANAGER_MAX_BYTES" \
  "Extract responsibilities into focused controllers under Runtime/TabManager/Controllers (activation/attachment/restore/budget/session/plugin/observer)."

check_dir_budget_each_file \
  "RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/Controllers" \
  "$WEBOS_BUDGET_TABMANAGER_CONTROLLER_MAX_LINES" \
  "$WEBOS_BUDGET_TABMANAGER_CONTROLLER_MAX_BYTES" \
  "Keep each controller single-purpose. If it grows: extract a new controller (e.g. TabSelectionController) or move runtime-only logic into CoreKit and expose a protocol surface."

check_file_budget \
  "RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/ViewModel/SplitBrowserViewModel.swift" \
  "$WEBOS_BUDGET_SPLITBROWSER_VM_MAX_LINES" \
  "$WEBOS_BUDGET_SPLITBROWSER_VM_MAX_BYTES" \
  "Extract UI concerns into smaller domains/controllers (AddressBar/Tabs/Layout) and push runtime mutations behind the intent boundary."

check_file_budget \
  "RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Plugins/Runtime/PluginHost.swift" \
  "$WEBOS_BUDGET_PLUGINHOST_MAX_LINES" \
  "$WEBOS_BUDGET_PLUGINHOST_MAX_BYTES" \
  "Extract plugin protocols/adapters; move WebKit/runtime-only details down (CoreKit) and keep UI glue in SafariLikeKit."

check_file_budget \
  "RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Platform/Web/WebView.swift" \
  "$WEBOS_BUDGET_WEBVIEW_MAX_LINES" \
  "$WEBOS_BUDGET_WEBVIEW_MAX_BYTES" \
  "Split WebView into smaller pieces (handle vs. representable vs. instrumentation) and keep WKWebView creation sealed in CoreKit."

echo "[repo-guard] Checking duplicate Swift content..."
check_duplicate_swift_content

echo "[repo-guard] Checking duplicate utility filenames..."
check_duplicate_utility_filenames

echo "[repo-guard] Checking risky duplicate utility basenames..."
check_duplicate_risky_utility_basenames

echo "[repo-guard] Checking repeated utility symbol names (heuristic)..."
check_duplicate_utility_type_names

if [[ "$WEBOS_ENFORCE_WKWEBVIEW_FACTORY" == "1" ]]; then
  echo "[repo-guard] Enforcing WKWebView construction boundary..."
  check_wkwebview_constructors
else
  echo "[repo-guard] note: WEBOS_ENFORCE_WKWEBVIEW_FACTORY=0 so WKWebView constructor guard is disabled" >&2
fi

if [[ "$WEBOS_ENFORCE_SINGLETON_REGRESSION_GUARD" == "1" ]]; then
  echo "[repo-guard] Enforcing singleton regression guard (SafariLikeKit)..."
  check_new_safarilikekit_shared_singletons
else
  echo "[repo-guard] note: WEBOS_ENFORCE_SINGLETON_REGRESSION_GUARD=0 so singleton regression guard is disabled" >&2
fi

echo "[repo-guard] Running architecture checks..."
"$ROOT_DIR/Dev/Tools/Scripts/architecture_check.sh"

echo "[repo-guard] OK: anti-bloat guardrails passed"
