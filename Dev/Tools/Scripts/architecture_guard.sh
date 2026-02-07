#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

APP_DIR="$REPO_ROOT/App"

# ------------------------------------------------------------
# Config (tweak here; keep rules below stable)
# ------------------------------------------------------------

# Rule 1) /App import boundary
APP_DISALLOWED_IMPORTS_REGEX='SafariLikeUIKit|SafariLikeCoreKit|BrowserCore|SafariLikeUXKit'

# Rule 2) WKWebView construction boundary
ALLOWED_WKWEBVIEW_FILE="RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift"
ALLOWED_WKWEBVIEW_PATH="$REPO_ROOT/$ALLOWED_WKWEBVIEW_FILE"

# Rule 3) Singleton forbidden patterns (heuristic)
SINGLETON_OPT_OUT_MARKER='// ARCH_GUARD:ALLOW_SINGLETON_STATE'
SINGLETON_SHARED_DECL_REGEX='static[[:space:]]+let[[:space:]]+shared\b|class[[:space:]]+var[[:space:]]+shared\b'

# If a file declares a shared singleton AND contains any of these keywords, it is flagged.
SINGLETON_SUSPICIOUS_STATE_KEYWORDS_REGEX='tabID|sceneID|windowID|TabID|SceneID|WindowID|Dictionary|NSCache|cache|cached|registry|registries|WeakMap|LRU|map|maps'
SINGLETON_SUSPICIOUS_UI_KEYWORDS_REGEX='WKWebView|UIViewController|Coordinator'

# Optional script-only exceptions for Rule 3 (path substrings, repo-relative).
# Prefer in-file opt-out marker when possible; use this sparingly for known-safe false positives.
SINGLETON_RULE3_ALLOW_PATH_SUBSTRINGS=(
)

# Rule 4) Scene-owned services must not be global (.shared)
SCENE_OWNED_TYPES_FORBID_SHARED=(
  SceneRuntimeContext
  TabRegistry
)

have_rg() {
  command -v rg >/dev/null 2>&1
}

is_allowed_by_rule3_path() {
  local file="$1"
  local rel="${file#"$REPO_ROOT"/}"
  local allow
  for allow in "${SINGLETON_RULE3_ALLOW_PATH_SUBSTRINGS[@]:-}"; do
    [[ -z "$allow" ]] && continue
    if [[ "$rel" == *"$allow"* ]]; then
      return 0
    fi
  done
  return 1
}

print_matches() {
  # usage: print_matches <regex> <file>
  local regex="$1"
  local file="$2"
  if have_rg; then
    rg -n --no-heading --color=never -S -e "$regex" "$file" || true
  else
    grep -nE "$regex" "$file" || true
  fi
}

failures=0

echo "[architecture-guard] repo: $REPO_ROOT"

# ------------------------------------------------------------
# Rule 1) App must not import lower layers
# ------------------------------------------------------------
rule1_pattern="^[[:space:]]*import[[:space:]]+(${APP_DISALLOWED_IMPORTS_REGEX})\\b"

rule1_hits=""
if [[ -d "$APP_DIR" ]]; then
  if have_rg; then
    rule1_hits="$(rg -n --no-heading --color=never -S -g'*.swift' "$rule1_pattern" "$APP_DIR" || true)"
  else
    rule1_hits="$(grep -RInE --include='*.swift' "$rule1_pattern" "$APP_DIR" || true)"
  fi
fi

if [[ -n "$rule1_hits" ]]; then
  echo
  echo "ERROR: /App must not import lower layers: SafariLikeUIKit, SafariLikeCoreKit, BrowserCore, SafariLikeUXKit"
  echo "$rule1_hits"
  failures=$((failures + 1))
else
  echo "[ok] App import boundary"
fi

# ------------------------------------------------------------
# Rule 2) WKWebView must only be constructed in WebViewPool.swift
# ------------------------------------------------------------
# We search for the literal constructor token 'WKWebView('.
# This intentionally catches both 'WKWebView(' and 'WKWebView(frame:...)'.

wk_pattern='WKWebView\('
wk_hits=""

if have_rg; then
  # Search only in Swift sources to avoid false positives in logs/docs.
  wk_hits="$(rg -n --no-heading --color=never -S -g'*.swift' --fixed-string 'WKWebView(' \
    --glob '!**/.git/**' \
    --glob '!**/.build/**' \
    --glob '!**/DerivedData/**' \
    --glob '!**/SourcePackages/**' \
    --glob "!$ALLOWED_WKWEBVIEW_FILE" \
    "$REPO_ROOT" || true)"
else
  # grep fallback
  wk_hits="$(grep -RInF --include='*.swift' 'WKWebView(' "$REPO_ROOT" \
    --exclude-dir='.git' \
    --exclude-dir='.build' \
    --exclude-dir='DerivedData' \
    --exclude-dir='SourcePackages' \
    || true)"
  if [[ -n "$wk_hits" ]]; then
    wk_hits="$(echo "$wk_hits" | grep -vF "$ALLOWED_WKWEBVIEW_PATH" || true)"
  fi
fi

if [[ -n "$wk_hits" ]]; then
  echo
  echo "ERROR: WKWebView must only be constructed in: $ALLOWED_WKWEBVIEW_FILE"
  echo "Offending occurrences of 'WKWebView(' (excluding allowlist):"
  echo "$wk_hits"
  failures=$((failures + 1))
else
  echo "[ok] WKWebView construction boundary"
fi

# ------------------------------------------------------------
# Rule 3) Singleton forbidden patterns (heuristic -> CI error)
# ------------------------------------------------------------

singleton_files=""
if have_rg; then
  singleton_files="$(
    rg -l --color=never -S -g'*.swift' -e "$SINGLETON_SHARED_DECL_REGEX" \
      --glob '!**/.git/**' \
      --glob '!**/.build/**' \
      --glob '!**/DerivedData/**' \
      --glob '!**/SourcePackages/**' \
      "$REPO_ROOT" || true
  )"
else
  # grep fallback: find swift files and check per-file
  singleton_files="$(
    find "$REPO_ROOT" \
      -type f -name '*.swift' \
      -not -path '*/.git/*' \
      -not -path '*/.build/*' \
      -not -path '*/DerivedData/*' \
      -not -path '*/SourcePackages/*' \
      -print0 \
      | xargs -0 grep -lE "$SINGLETON_SHARED_DECL_REGEX" 2>/dev/null \
      || true
  )"
fi

rule3_violations=0
rule3_report=""

if [[ -n "$singleton_files" ]]; then
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    if is_allowed_by_rule3_path "$file"; then
      continue
    fi

    if grep -qF "$SINGLETON_OPT_OUT_MARKER" "$file"; then
      continue
    fi

    # If the file contains any suspicious keywords, flag it.
    if have_rg; then
      if rg -q -S -e "$SINGLETON_SUSPICIOUS_STATE_KEYWORDS_REGEX" "$file" || rg -q -S -e "$SINGLETON_SUSPICIOUS_UI_KEYWORDS_REGEX" "$file"; then
        rule3_violations=$((rule3_violations + 1))
        rule3_report+=$'\n'
        rule3_report+="$file"$'\n'
        rule3_report+="$(print_matches "$SINGLETON_SHARED_DECL_REGEX|$SINGLETON_SUSPICIOUS_STATE_KEYWORDS_REGEX|$SINGLETON_SUSPICIOUS_UI_KEYWORDS_REGEX" "$file")"$'\n'
      fi
    else
      if grep -qE "$SINGLETON_SUSPICIOUS_STATE_KEYWORDS_REGEX" "$file" || grep -qE "$SINGLETON_SUSPICIOUS_UI_KEYWORDS_REGEX" "$file"; then
        rule3_violations=$((rule3_violations + 1))
        rule3_report+=$'\n'
        rule3_report+="$file"$'\n'
        rule3_report+="$(print_matches "$SINGLETON_SHARED_DECL_REGEX|$SINGLETON_SUSPICIOUS_STATE_KEYWORDS_REGEX|$SINGLETON_SUSPICIOUS_UI_KEYWORDS_REGEX" "$file")"$'\n'
      fi
    fi
  done <<< "$singleton_files"
fi

if [[ "$rule3_violations" -ne 0 ]]; then
  echo
  echo "ERROR: Singleton state heuristic triggered ($rule3_violations file(s))."
  echo "Any file declaring 'shared' must not retain scene/tab/window-scoped mutable state or UI objects."
  echo "Move state under SceneRuntimeContext (scene-owned) or tab-owned stores (TabRegistry/TabWebStore), or refactor to injected instances."
  echo
  echo "Opt-out (rare): add this marker inside the file to silence Rule 3 only for that file:"
  echo "  $SINGLETON_OPT_OUT_MARKER"
  echo
  echo "Matches:"
  echo "$rule3_report"
  failures=$((failures + 1))
else
  echo "[ok] Singleton state heuristic"
fi

# ------------------------------------------------------------
# Rule 4) Scene-owned services must not be global (.shared)
# ------------------------------------------------------------

rule4_hits=""

# Hard forbid these exact patterns.
rule4_pattern_hard='\\b(SceneRuntimeContext|TabRegistry)\\.shared\\b'

if have_rg; then
  rule4_hits="$(
    rg -n --no-heading --color=never -S -g'*.swift' -e "$rule4_pattern_hard" \
      --glob '!**/.git/**' \
      --glob '!**/.build/**' \
      --glob '!**/DerivedData/**' \
      --glob '!**/SourcePackages/**' \
      "$REPO_ROOT" || true
  )"
else
  rule4_hits="$(
    grep -RInE --include='*.swift' "$rule4_pattern_hard" "$REPO_ROOT" \
      --exclude-dir='.git' \
      --exclude-dir='.build' \
      --exclude-dir='DerivedData' \
      --exclude-dir='SourcePackages' \
      || true
  )"
fi

# Configurable forbid list.
for t in "${SCENE_OWNED_TYPES_FORBID_SHARED[@]}"; do
  pattern="\\b${t}\\.shared\\b"
  if have_rg; then
    hits="$(
      rg -n --no-heading --color=never -S -g'*.swift' -e "$pattern" \
        --glob '!**/.git/**' \
        --glob '!**/.build/**' \
        --glob '!**/DerivedData/**' \
        --glob '!**/SourcePackages/**' \
        "$REPO_ROOT" || true
    )"
  else
    hits="$(
      grep -RInE --include='*.swift' "$pattern" "$REPO_ROOT" \
        --exclude-dir='.git' \
        --exclude-dir='.build' \
        --exclude-dir='DerivedData' \
        --exclude-dir='SourcePackages' \
        || true
    )"
  fi
  if [[ -n "$hits" ]]; then
    rule4_hits+=$'\n'
    rule4_hits+="$hits"
  fi
done

if [[ -n "$rule4_hits" ]]; then
  echo
  echo "ERROR: Scene-owned services must not be global singletons (.shared)."
  echo "Matches:"
  echo "$rule4_hits"
  failures=$((failures + 1))
else
  echo "[ok] No forbidden scene-owned .shared usage"
fi

# ------------------------------------------------------------
# Final
# ------------------------------------------------------------
if [[ "$failures" -ne 0 ]]; then
  echo
  echo "[architecture-guard] FAIL ($failures rule(s) violated)"
  exit 2
fi

echo "[architecture-guard] OK"
