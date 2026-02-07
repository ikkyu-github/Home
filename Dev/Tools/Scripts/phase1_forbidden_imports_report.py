#!/usr/bin/env python3
"""Phase 1 forbidden-import report (Safari-like layering).

Outputs a markdown table focused on violations, not every file.

This intentionally avoids pbxproj parsing; it uses folder layout heuristics:
- App/ -> module "App"
- RuntimePackages/<Pkg>/Sources/<Target>/... -> module <Target>

Rules encoded here match the Phase 1 request:
- App must not import BrowserCore or SafariLikeCoreKit directly
- UI folders (SwiftUI files or under /UI/) must not import BrowserCore or SafariLikeCoreKit
- Plugins/Examples must be contracts-only
- SafariLikeUIKit must not import SafariLikeCoreKit/BrowserCore (host must use facade + contracts)

Run:
    # Preferred: use dependency_graph.json (includes exact rule + file + line).
    python3 Dev/Tools/Scripts/phase1_forbidden_imports_report.py \
        --json build_logs/dependency_graph.json \
        --out Docs/Architecture/Phase1/forbidden_imports.md

    # Fallback: direct source scan (no rule IDs).
    python3 Dev/Tools/Scripts/phase1_forbidden_imports_report.py \
        --scan \
        --out Docs/Architecture/Phase1/forbidden_imports.md
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Optional, Sequence

IMPORT_RE = re.compile(r"^\s*(?:@testable\s+)?import\s+([A-Za-z_][A-Za-z0-9_]*)\b")


def find_workspace_root(start: Path) -> Path:
    for p in [start] + list(start.parents):
        if (p / "RuntimePackages").exists() and (p / "App").exists():
            return p
        if (p / "RuntimePackages").exists() and (p / "webOS.xcodeproj").exists():
            return p
    return start


@dataclass(frozen=True)
class ImportHit:
    file: str
    line: int
    module: str
    imported: str
    raw: str
    reason: str
    fix: str


def default_violation_fixes(rule: str, module: str, imported: str, file: str) -> tuple[str, str]:
    # Keep these intentionally high-level; PR-01 will specify exact moves per file group.
    if rule == "UI.should_not_import_Core_directly_use_Contracts":
        return (
            "UI layer importing Core/Engine types directly",
            "Move needed protocols/value types into SafariLikeContracts; inject adapters via facade/runtime glue",
        )

    if rule == "Layering.lower_layer_imports_higher_layer":
        return (
            f"Layering inversion: {module} must not import higher layer",
            "Introduce a facade target (or move shared types to SafariLikeContracts) so lower layers depend only downward",
        )

    if "Plugin" in file and imported != "SafariLikeContracts":
        return (
            "Plugin implementations must be Contracts-only",
            "Move plugin implementations into a non-UI runtime module, or refactor plugin APIs so implementations depend only on SafariLikeContracts",
        )

    if module == "SafariLikeUIKit" and imported in {"SafariLikeCoreKit", "BrowserCore"}:
        return (
            "UIKit host must not import engine internals",
            "Route through SafariLikeKit facade + SafariLikeContracts; move engine-touching code out of SafariLikeUIKit",
        )

    return (
        f"Forbidden import per rule: {rule}",
        "Refactor to maintain strict layer boundaries (prefer SafariLikeContracts for shared types and a facade for orchestration)",
    )


def load_hits_from_dependency_graph_json(root: Path, json_path: Path) -> List[ImportHit]:
    data = json.loads(json_path.read_text(encoding="utf-8"))
    violations = data.get("violations", [])
    hits: List[ImportHit] = []

    for v in violations:
        file = v.get("file")
        if not file:
            continue
        imported = v.get("imported") or ""
        rule = v.get("rule") or "(unknown-rule)"
        module = v.get("module") or owner_module_for(root, root / file)
        line = int(v.get("line") or 0)
        raw = v.get("import") or f"import {imported}".strip()
        reason, fix = default_violation_fixes(rule, module, imported, file)

        hits.append(
            ImportHit(
                file=file,
                line=line,
                module=module,
                imported=imported,
                raw=raw,
                reason=reason,
                fix=fix,
            )
        )

    return hits


def iter_swift_files(root: Path) -> Iterable[Path]:
    for p in root.rglob("*.swift"):
        if "/.build/" in str(p):
            continue
        if "/DerivedData/" in str(p):
            continue
        yield p


def owner_module_for(root: Path, path: Path) -> str:
    rel = path.relative_to(root)
    parts = rel.parts

    if parts and parts[0] == "App":
        return "App"

    # RuntimePackages/<Pkg>/Sources/<Target>/...
    if len(parts) >= 4 and parts[0] == "RuntimePackages" and parts[2] == "Sources":
        return parts[3]

    # RuntimePackages/<Pkg>/Tests/<Target>/...
    if len(parts) >= 4 and parts[0] == "RuntimePackages" and parts[2] == "Tests":
        return parts[3]

    return "(unknown)"


def file_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8", errors="ignore")


def is_swiftui_file(text: str) -> bool:
    return re.search(r"^\s*import\s+SwiftUI\b", text, flags=re.MULTILINE) is not None


def classify_reason_and_fix(owner: str, rel: str, imported: str, *, swiftui: bool) -> Optional[tuple[str, str]]:
    # 1) App must not import core/engine directly.
    if owner == "App" and imported in {"BrowserCore", "SafariLikeCoreKit"}:
        return (
            "App must not import engine/core directly",
            "Route through SafariLikeKit facade (or add a Contracts wrapper for needed value types)",
        )

    # 2) UI files must not import core.
    is_ui_path = "/UI/" in rel or "/Views/" in rel or "/ViewModel/" in rel or swiftui
    if owner == "SafariLikeKit" and is_ui_path and imported in {"BrowserCore", "SafariLikeCoreKit"}:
        return (
            "UI layer must not import core/engine",
            "Move required types into SafariLikeContracts (protocols/value types) and inject via facade",
        )

    # 3) Example plugins must be contracts-only.
    if "/Plugins/Examples/" in rel and imported in {"BrowserCore", "SafariLikeCoreKit", "SafariLikeKit"}:
        return (
            "Plugin implementations must be Contracts-only",
            "Depend only on SafariLikeContracts and have runtime register adapters in a non-UI module",
        )

    # 4) UIKit host should not import engine internals.
    if owner == "SafariLikeUIKit" and imported in {"SafariLikeCoreKit", "BrowserCore"}:
        return (
            "UIKit host must not import engine internals",
            "Use SafariLikeKit facade + SafariLikeContracts only; move engine-touching code into SafariLikeKit runtime glue",
        )

    # 5) Re-export leaks (handled separately by caller).
    return None


def scan(root: Path) -> List[ImportHit]:
    hits: List[ImportHit] = []

    for path in iter_swift_files(root):
        rel = str(path.relative_to(root))
        text = file_text(path)
        owner = owner_module_for(root, path)
        swiftui = is_swiftui_file(text)

        for idx, raw in enumerate(text.splitlines(), start=1):
            m = IMPORT_RE.match(raw)
            if not m:
                continue
            imported = m.group(1)

            # Flag re-export coupling.
            if "@_exported" in raw and imported in {"BrowserCore", "SafariLikeCoreKit"}:
                hits.append(
                    ImportHit(
                        file=rel,
                        line=idx,
                        module=owner,
                        imported=imported,
                        raw=raw.strip(),
                        reason="Hidden coupling via @_exported import",
                        fix="Remove re-export; add explicit imports where needed and expose stable Contracts/facade APIs",
                    )
                )
                continue

            rule = classify_reason_and_fix(owner, rel, imported, swiftui=swiftui)
            if not rule:
                continue
            reason, fix = rule
            hits.append(
                ImportHit(
                    file=rel,
                    line=idx,
                    module=owner,
                    imported=imported,
                    raw=raw.strip(),
                    reason=reason,
                    fix=fix,
                )
            )

    return hits


def write_markdown(out: Path, hits: Sequence[ImportHit]) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)

    def esc(s: str) -> str:
        return s.replace("|", "\\|")

    with out.open("w", encoding="utf-8") as f:
        f.write("# Phase 1 — Forbidden Imports (Safari-like Layering)\n\n")
        f.write("This report lists only *violations* (not all imports).\n\n")
        f.write("| File | Line | Owner Module | Import | Why | Suggested Fix |\n")
        f.write("|---|---:|---|---|---|---|\n")

        for h in hits:
            f.write(
                "| {file} | {line} | {module} | {imported} | {why} | {fix} |\n".format(
                    file=esc(h.file),
                    line=h.line,
                    module=esc(h.module),
                    imported=esc(h.raw),
                    why=esc(h.reason),
                    fix=esc(h.fix),
                )
            )

        f.write("\n## Summary\n\n")
        f.write(f"- Violations: {len(hits)}\n")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    ap.add_argument("--json", default=None, help="Path to build_logs/dependency_graph.json (preferred input)")
    ap.add_argument("--scan", action="store_true", help="Force scanning sources instead of reading JSON")
    ap.add_argument("--out", default="Docs/Architecture/Phase1/forbidden_imports.md")
    args = ap.parse_args()

    root = find_workspace_root(Path(args.root).resolve())

    hits: List[ImportHit]
    if not args.scan:
        json_arg = args.json
        candidate = (root / "build_logs" / "dependency_graph.json")
        json_path = Path(json_arg).expanduser() if json_arg else candidate
        if not json_path.is_absolute():
            json_path = (root / json_path).resolve()

        if json_path.exists():
            hits = load_hits_from_dependency_graph_json(root, json_path)
        else:
            hits = scan(root)
    else:
        hits = scan(root)

    hits_sorted = sorted(hits, key=lambda h: (h.module, h.file, h.line, h.imported))

    out = root / args.out
    write_markdown(out, hits_sorted)
    print(f"Wrote {out} ({len(hits_sorted)} violations)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
