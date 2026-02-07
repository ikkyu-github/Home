#!/usr/bin/env bash
set -euo pipefail

# Phase 1 rerun script (Safari-like audit)
# - regenerates build_logs/dependency_graph.{md,json}
# - regenerates Docs/Architecture/Phase1/forbidden_imports.md

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

cd "$ROOT"

echo "[phase1] root: $ROOT"

echo "[phase1] generating dependency graph"
python3 Dev/Tools/Scripts/dependency_graph.py

echo "[phase1] generating forbidden imports report"
python3 Dev/Tools/Scripts/phase1_forbidden_imports_report.py \
  --json build_logs/dependency_graph.json \
  --out Docs/Architecture/Phase1/forbidden_imports.md

echo "[phase1] done"
echo "- build_logs/dependency_graph.md"
echo "- build_logs/dependency_graph.json"
echo "- Docs/Architecture/Phase1/forbidden_imports.md"
