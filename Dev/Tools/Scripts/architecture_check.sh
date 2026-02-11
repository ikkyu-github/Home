#!/usr/bin/env bash
set -euo pipefail

ROOT="${SRCROOT:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"}"

CI_MODE=0
if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
  CI_MODE=1
fi

usage() {
  cat <<'EOF'
architecture_check.sh — enforce module layering & SSOT guards

Usage:
  Dev/Tools/Scripts/architecture_check.sh [--ci]

Options:
  --ci   Require developer tooling (e.g. ripgrep) and fail fast if missing.

What it checks:
  1) App must not import BrowserCore / SafariLikeCoreKit / SafariLikeUXKit
  1b) App must not reference TabManager/BrowserTabManaging (use intent API)
  2) BrowserCore must not import UIKit / SwiftUI / WebKit
  3) SafariLikeCoreKit must not import UIKit / SwiftUI / AppKit
  4) SafariLikeKit must not import/re-export BrowserCore
  4b) (Optional) SafariLikeKit must not import SafariLikeCoreKit (set WEBOS_ENFORCE_SAFARILIKEKIT_NO_COREKIT=1)
  5) WKWebView constructors must live only in WebViewPool.swift
  6) WebViewPool.shared must not exist (no global pool)
  7) Key SSOT symbol names must not be defined in multiple modules
  8) WebView attach/activate calls must be runtime-internal only

Exit codes:
  0  OK
  1  violations found
  2  invalid arguments or missing required tooling
EOF
}

case "${1:-}" in
  --ci)
    CI_MODE=1
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    echo "error: unknown argument: $1" >&2
    usage >&2
    exit 2
    ;;
esac

USE_RG=0
if command -v rg >/dev/null 2>&1; then
  USE_RG=1
else
  if [[ "$CI_MODE" -eq 1 ]]; then
    echo "error: ripgrep (rg) is required in CI mode. Install with: brew install ripgrep" >&2
    exit 2
  fi
  echo "note: ripgrep (rg) not found; falling back to grep (slower). Install with: brew install ripgrep" >&2
fi

fail=0

banner() {
  printf "\n== %s ==\n" "$1"
}

note() {
  printf "%s\n" "$1"
}

report_matches() {
  local title="$1"
  local matches="$2"

  banner "$title"
  printf "%s\n" "$matches"
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
    # PR builds: compare against the base branch.
    local base_ref="origin/${GITHUB_BASE_REF}"
    if git rev-parse --verify "$base_ref" >/dev/null 2>&1; then
      diff_range="$base_ref...HEAD"
    fi
  fi

  if [[ -z "$diff_range" ]]; then
    # Push builds/local: compare against previous commit when available.
    if git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
      diff_range="HEAD~1..HEAD"
    fi
  fi

  [[ -z "$diff_range" ]] && return 0

  # Parse `git diff -U0` to map added lines to (file, line number).
  git diff --unified=0 $diff_range -- "$path" \
    | awk -v re="$added_regex" '
        BEGIN { file=""; ln=0 }
        /^\+\+\+ b\// { file=substr($0,7); next }
        /^@@/ {
          # Example: @@ -12,0 +13,3 @@
          if (match($0, /\+[0-9]+/)) {
            ln = substr($0, RSTART+1, RLENGTH-1)
          }
          next
        }
        /^\+/ {
          if ($0 ~ /^\+\+\+/) next
          if (file != "") {
            line = substr($0, 2)
            if (line ~ re) {
              printf "%s:%d:%s\n", file, ln, line
            }
            ln++
          }
          next
        }
      ' \
    || true
}

rg_matches() {
  # Usage: rg_matches <regex> <path>
  local regex="$1"
  local path="$2"
  if [[ "$USE_RG" -eq 1 ]]; then
    rg -n --no-heading --color never --hidden --glob '!.git/**' --glob '!**/*.pbxproj' "$regex" "$path" 2>/dev/null || true
  else
    grep -RIn --include='*.swift' -E "$regex" "$path" 2>/dev/null || true
  fi
}

check_app_layering() {
  local dir="$ROOT/App"
  if [[ ! -d "$dir" ]]; then
    note "warning: App dir not found at: $dir"
    return 0
  fi

  # App target may only import SafariLikeKit + SafariLikeContracts (+ Apple frameworks).
  local forbidden='^[[:space:]]*(@_implementationOnly[[:space:]]+)?(@_exported[[:space:]]+)?import[[:space:]]+(BrowserCore|SafariLikeCoreKit|SafariLikeUXKit)([[:space:]]|$)'
  local matches
  matches="$(rg_matches "$forbidden" "$dir")"
  if [[ -n "$matches" ]]; then
    report_matches "ERROR: App must not import BrowserCore/CoreKit/UXKit (App imports only SafariLikeKit + SafariLikeContracts)" "$matches"
    fail=1
  fi
}

check_browsercore_purity() {
  local dir="$ROOT/RuntimePackages/BrowserCore/Sources/BrowserCore"
  if [[ ! -d "$dir" ]]; then
    note "warning: BrowserCore sources not found at: $dir"
    return 0
  fi

  # BrowserCore must stay platform-agnostic (no UI/WebKit).
  local forbidden='^[[:space:]]*(@_implementationOnly[[:space:]]+)?(@_exported[[:space:]]+)?import[[:space:]]+(UIKit|SwiftUI|WebKit)([[:space:]]|$)'
  local matches
  matches="$(rg_matches "$forbidden" "$dir")"
  if [[ -n "$matches" ]]; then
    report_matches "ERROR: BrowserCore must not import UIKit/SwiftUI/WebKit (BrowserCore imports only SafariLikeContracts + Foundation)" "$matches"
    fail=1
  fi
}

check_corekit_purity() {
  local dir="$ROOT/RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit"
  if [[ ! -d "$dir" ]]; then
    note "warning: SafariLikeCoreKit sources not found at: $dir"
    return 0
  fi

  # CoreKit must not import UI frameworks.
  # WebKit is allowed (CoreKit is the WebKit integration layer).
  local forbidden='^[[:space:]]*(@_implementationOnly[[:space:]]+)?(@_exported[[:space:]]+)?import[[:space:]]+(UIKit|SwiftUI|AppKit)([[:space:]]|$)'
  local matches
  matches="$(rg_matches "$forbidden" "$dir")"
  if [[ -n "$matches" ]]; then
    report_matches "ERROR: SafariLikeCoreKit must not import UIKit/SwiftUI/AppKit" "$matches"
    fail=1
  fi
}

check_safarilikekit_no_browsercore() {
  local dir="$ROOT/RuntimePackages/SafariLikeKit/Sources/SafariLikeKit"
  if [[ ! -d "$dir" ]]; then
    note "warning: SafariLikeKit sources not found at: $dir"
    return 0
  fi

  # SafariLikeKit is a facade layer and must not depend on BrowserCore directly.
  local forbidden='^[[:space:]]*(@_implementationOnly[[:space:]]+)?(@_exported[[:space:]]+)?import[[:space:]]+BrowserCore([[:space:]]|$)'
  local matches
  matches="$(rg_matches "$forbidden" "$dir")"
  if [[ -n "$matches" ]]; then
    report_matches "ERROR: SafariLikeKit must not import or re-export BrowserCore" "$matches"
    fail=1
  fi
}

check_no_new_safarilikekit_corekit_imports() {
  # Safari-grade: new direct dependencies from SafariLikeKit -> CoreKit are almost always
  # architecture regressions. Existing legacy imports are tolerated for now; this guard
  # prevents *new* ones from accreting silently.
  local dir="$ROOT/RuntimePackages/SafariLikeKit/Sources/SafariLikeKit"
  if [[ ! -d "$dir" ]]; then
    return 0
  fi

  local matches
  matches="$(git_added_line_matches "RuntimePackages/SafariLikeKit/Sources/SafariLikeKit" '^[[:space:]]*(@_implementationOnly[[:space:]]+)?(@_exported[[:space:]]+)?import[[:space:]]+SafariLikeCoreKit\\b')"

  if [[ -n "$matches" ]]; then
    report_matches "ERROR: Dependency boundary violation (SafariLikeKit layer): new 'import SafariLikeCoreKit' added (use SafariLikeContracts / intent APIs)" "$matches"
    note "Guidance: SafariLikeKit is a UI/facade layer. If you need runtime/WebKit behavior, move it down into SafariLikeCoreKit and expose a protocol surface via SafariLikeContracts."
    note "Docs: ARCHITECTURE.md + Docs/ARCHITECTURE_GUARDRAILS.md"
    fail=1
  fi
}

check_safarilikekit_no_corekit() {
  # Optional tightening: SafariLikeKit should ideally depend on Contracts + intent API,
  # not CoreKit implementation details.
  #
  # Default is OFF because legacy ViewModel/runtime glue still exists.
  if [[ "${WEBOS_ENFORCE_SAFARILIKEKIT_NO_COREKIT:-0}" != "1" ]]; then
    return 0
  fi

  local dir="$ROOT/RuntimePackages/SafariLikeKit/Sources/SafariLikeKit"
  if [[ ! -d "$dir" ]]; then
    note "warning: SafariLikeKit sources not found at: $dir"
    return 0
  fi

  local forbidden='^[[:space:]]*(@_implementationOnly[[:space:]]+)?(@_exported[[:space:]]+)?import[[:space:]]+SafariLikeCoreKit([[:space:]]|$)'
  local matches
  matches="$(rg_matches "$forbidden" "$dir")"
  if [[ -n "$matches" ]]; then
    report_matches "ERROR: SafariLikeKit must not import SafariLikeCoreKit (enable was requested)" "$matches"
    note "Guidance: move runtime-only logic down into CoreKit and expose UI-facing APIs via SafariLikeContracts + BrowserSceneSession.send(intent:)."
    fail=1
  fi
}

check_app_intent_boundary() {
  local dir="$ROOT/App"
  if [[ ! -d "$dir" ]]; then
    note "warning: App dir not found at: $dir"
    return 0
  fi

  # App must not depend on runtime TabManager/BrowserTabManaging or the old environment key.
  # Keep patterns specific to avoid false positives (App may have unrelated 'tabManager' variables).
  local forbidden='\\b(session|sceneRoot\\.session)\\??\\.tabManager\\b|\\.browserTabManager\\b|\\bBrowserTabManaging\\b'
  local matches
  matches="$(rg_matches "$forbidden" "$dir")"
  if [[ -n "$matches" ]]; then
    report_matches "ERROR: App must not reach into runtime internals (use BrowserSceneSession.send(intent:) + browserRuntime env)" "$matches"
    fail=1
  fi
}

check_no_attachment_calls_outside_runtime() {
  # Guardrail: direct attach/activate/deactivate calls must not leak to non-runtime layers.
  # This complements the single-writer runtime enforcement.
  local matches
  if [[ "$USE_RG" -eq 1 ]]; then
    matches="$(
      rg -n --no-heading --color never --hidden --glob '!.git/**' --glob '!**/*.pbxproj' \
        --glob 'RuntimePackages/**/Sources/**/*.swift' \
        '\\b(forceAttachWebView|attachWebView|detachWebView|activateWebView|deactivateWebView)\\b' \
        "$ROOT" \
        | rg -v 'RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/(Runtime|Platform)/' \
        | rg -v 'RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/(Runtime|WebKit)/' \
        || true
    )"
  else
    # Grep fallback: slightly noisier than rg but keeps CI strict without extra tooling.
    matches="$(
      grep -RIn --include='*.swift' -E '\\b(forceAttachWebView|attachWebView|detachWebView|activateWebView|deactivateWebView)\\b' \
        "$ROOT/RuntimePackages" 2>/dev/null \
        | grep -v 'RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/' \
        | grep -v 'RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Platform/' \
        | grep -v 'RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/' \
        | grep -v 'RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/' \
        || true
    )"
  fi
  if [[ -n "$matches" ]]; then
    report_matches "ERROR: WebView attach/activate calls must be runtime-internal only" "$matches"
    fail=1
  fi
}

check_wkwebview_construction_sealed() {
  # Enforce: WKWebView(...) constructors must only appear inside WebViewPool.swift.
  # Keep this as an rg-only check to avoid brittle grep heuristics.
  local sources_root="$ROOT/RuntimePackages"
  if [[ ! -d "$sources_root" ]]; then
    note "warning: RuntimePackages not found at: $sources_root"
    return 0
  fi

  local matches
  if [[ "$USE_RG" -eq 1 ]]; then
    matches="$(
      rg -n --no-heading --color never --hidden --glob '!.git/**' --glob '!**/*.pbxproj' \
        --glob 'RuntimePackages/**/Sources/**/*.swift' \
        'WKWebView|WebView' \
        "$ROOT" \
        | rg -v 'WebViewPool\\.swift:' \
        | grep -Ev '^[[:space:]]*//' \
        || true
    )"
  else
    # Grep fallback: best-effort constructor seal.
    matches="$(
      grep -RIn --include='*.swift' -E 'WKWebView[[:space:]]*\(|WKWebView\.init[[:space:]]*\(' \
        "$sources_root" 2>/dev/null \
        | grep -v 'WebViewPool\.swift:' \
        | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' \
        | awk -F: '
            {
              line=$0
              content=line
              sub(/^[^:]+:[0-9]+:/, "", content)

              # If the match is inside a quoted string, ignore it.
              matchpos = index(content, "WKWebView")
              if (matchpos == 0) { print line; next }

              prefix = substr(content, 1, matchpos-1)
              quoteCount = gsub(/\"/, "", prefix)
              if ((quoteCount % 2) == 1) { next }

              print line
            }
          ' \
        || true
    )"
  fi
  if [[ -n "$matches" ]]; then
    report_matches "ERROR: WKWebView constructors must live only in WebViewPool.swift" "$matches"
    fail=1
  fi
}

check_no_webviewpool_shared_fallbacks() {
  # Guardrail: runtime must not silently fall back to a global WebViewPool.
  # WebViewPool.shared must not exist.
  local sources_root="$ROOT/RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit"
  if [[ ! -d "$sources_root" ]]; then
    note "warning: SafariLikeCoreKit sources not found at: $sources_root"
    return 0
  fi

  local matches
  if [[ "$USE_RG" -eq 1 ]]; then
    matches="$(
      rg -n --no-heading --color never --hidden --glob '!.git/**' --glob '!**/*.pbxproj' \
        --glob 'RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/**/*.swift' \
        '\\bWebViewPool\\.shared\\b' \
        "$ROOT" \
        || true
    )"
  else
    matches="$(
      grep -RIn --include='*.swift' -E '\\bWebViewPool\\.shared\\b' \
        "$sources_root" 2>/dev/null \
        || true
    )"
  fi
  if [[ -n "$matches" ]]; then
    report_matches "ERROR: WebViewPool.shared is forbidden (no global pool)" "$matches"
    fail=1
  fi
}

module_from_path() {
  # Extract RuntimePackages/<Module>/Sources/... module name.
  # Prints empty string if not in a recognized module path.
  sed -E 's#^.*/RuntimePackages/([^/]+)/Sources/.*#\1#' <<< "$1" 2>/dev/null || true
}

dedupe_key_symbols() {
  # Guardrail: avoid duplicate SSOT types across modules.
  # Keep this list small + high-signal.
  local -a names=(
    "DefaultURLs"
    "WebsitePreferences"
    "WebsitePreferencesProviding"
  )

  local sources_root="$ROOT/RuntimePackages"
  if [[ ! -d "$sources_root" ]]; then
    note "warning: RuntimePackages not found at: $sources_root"
    return 0
  fi

  for name in "${names[@]}"; do
    local regex="^[[:space:]]*(public[[:space:]]+)?(enum|struct|class|protocol)[[:space:]]+${name}\\b"
    local matches
    matches="$(rg_matches "$regex" "$sources_root")"

    [[ -z "$matches" ]] && continue

    # Build a unique module list for this symbol.
    local modules
    modules="$(
      awk -F: '{print $1}' <<< "$matches" \
        | while IFS= read -r path; do module_from_path "$path"; done \
        | sed '/^$/d' \
        | sort -u
    )"

    local module_count
    module_count="$(wc -l <<< "$modules" | tr -d ' ')"

    if [[ "$module_count" -gt 1 ]]; then
      banner "ERROR: Duplicate symbol across modules: ${name}"
      note "Found definitions in modules:"
      printf "%s\n" "$modules" | sed 's/^/  - /'
      note "Matches:"
      printf "%s\n" "$matches"
      fail=1
    fi
  done
}

check_app_layering
check_app_intent_boundary
check_browsercore_purity
check_corekit_purity
check_safarilikekit_no_browsercore
check_no_new_safarilikekit_corekit_imports
check_safarilikekit_no_corekit
check_wkwebview_construction_sealed
check_no_webviewpool_shared_fallbacks
check_no_attachment_calls_outside_runtime
dedupe_key_symbols

if [[ "$fail" -ne 0 ]]; then
  echo "\nArchitecture enforcement failed." >&2
  exit 1
fi

echo "Architecture enforcement passed."
