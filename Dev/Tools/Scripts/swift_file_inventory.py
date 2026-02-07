#!/usr/bin/env python3
"""Full Swift file inventory + layering audit.

Generates a *complete* per-file table (not just violations):
- File → Role → Allowed deps → Actual deps → Violations

This complements:
- Dev/Tools/Scripts/dependency_graph.py (module graph)
- Dev/Tools/Scripts/phase1_forbidden_imports_report.py (violation-focused)

Usage:
  python3 Dev/Tools/Scripts/swift_file_inventory.py \
    --out Docs/Architecture/Phase1/swift_file_inventory.md

Notes:
- This is heuristic and intentionally conservative.
- The goal is Safari-grade layer hygiene, so it flags anything suspicious.
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Optional, Sequence, Set, Tuple

IMPORT_RE = re.compile(r"^\s*(?:@testable\s+)?import\s+([A-Za-z_][A-Za-z0-9_]*)\b")

IGNORE_DIR_PARTS = {
    ".git",
    ".build",
    "DerivedData",
    "SourcePackages",
    "Carthage",
    "Pods",
    "node_modules",
    "xcuserdata",
    "ModuleCache",
    "ModuleCache.noindex",
    "build",
}

ROLE_UI = "UI / View / Presentation"
ROLE_UI_ADAPTER = "UI Composition / Adapter"
ROLE_DOMAIN = "Domain Logic (state, reducers, engines)"
ROLE_RUNTIME = "Runtime / WebKit / IO"
ROLE_INFRA = "Infrastructure / Policy / Diagnostics"
ROLE_TEST = "Test / Example / Placeholder (❌ must not be in Sources)"

APPLE_MODULES = {
    "SwiftUI",
    "UIKit",
    "Foundation",
    "Combine",
    "WebKit",
    "OSLog",
    "os",
    "Darwin",
    "CoreGraphics",
    "QuartzCore",
    "AVFoundation",
    "UniformTypeIdentifiers",
    "QuickLook",
    "Security",
    "Network",
}

INTERNAL_TOP_MODULES = {
    "SafariLikeContracts",
    "BrowserCore",
    "SafariLikeCoreKit",
    "SafariLikeKit",
    "SafariLikeUIKit",
    "SafariLikeUXKit",
    "SafariLikeBuiltinPlugins",
    "webOS",
    "App",
}


def find_workspace_root(start: Path) -> Path:
    for p in [start] + list(start.parents):
        if (p / "RuntimePackages").exists() and (p / "App").exists():
            return p
        if (p / "RuntimePackages").exists() and (p / "webOS.xcodeproj").exists():
            return p
    return start


def iter_swift_files(root: Path) -> Iterable[Path]:
    for p in root.rglob("*.swift"):
        if any(part in IGNORE_DIR_PARTS for part in p.parts):
            continue
        yield p


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8", errors="ignore")


def parse_imports(text: str) -> List[str]:
    imports: List[str] = []
    for raw in text.splitlines():
        m = IMPORT_RE.match(raw)
        if m:
            imports.append(m.group(1))
    # preserve order but dedupe
    seen: Set[str] = set()
    out: List[str] = []
    for i in imports:
        if i in seen:
            continue
        seen.add(i)
        out.append(i)
    return out


def owner_module_for(root: Path, path: Path) -> str:
    rel = path.relative_to(root)
    parts = rel.parts

    if parts and parts[0] == "App":
        return "App"

    if parts and parts[0] == "webOSUITests":
        return "webOSUITests"

    # RuntimePackages/<Pkg>/Sources/<Target>/...
    if len(parts) >= 4 and parts[0] == "RuntimePackages" and parts[2] == "Sources":
        return parts[3]

    # RuntimePackages/<Pkg>/Tests/<Target>/...
    if len(parts) >= 4 and parts[0] == "RuntimePackages" and parts[2] == "Tests":
        return parts[3]

    return parts[0] if parts else "(root)"


def is_test_path(rel: str) -> bool:
    return (
        "/Tests/" in rel
        or rel.startswith("webOSUITests/")
        or rel.endswith("Tests.swift")
        or rel.endswith("UITests.swift")
    )


def is_exampleish(rel: str) -> bool:
    name = Path(rel).name
    if any(token in name for token in ("Example", "Demo", "Sandbox", "Playground", "Scratch")):
        return True
    if "/Examples/" in rel or "/Demo/" in rel or "/Sandbox/" in rel:
        return True
    return False


def classify_role(rel: str, owner: str, imports: Sequence[str], text: str) -> str:
    # Tests/examples/placeholder detection
    if is_test_path(rel) or is_exampleish(rel):
        return ROLE_TEST

    # Module-based hard rules
    if owner == "SafariLikeContracts":
        return ROLE_DOMAIN  # contracts are bottom layer; treat as domain primitives
    if owner == "BrowserCore":
        # heuristics by folder
        if "/Diagnostics/" in rel or "/Telemetry/" in rel or "/Policy/" in rel:
            return ROLE_INFRA
        if "/Downloads/" in rel or "/Session/" in rel or "/Reducers/" in rel or "/Engines/" in rel:
            return ROLE_DOMAIN
        return ROLE_DOMAIN
    if owner == "SafariLikeCoreKit":
        return ROLE_RUNTIME

    # UI / host / facade
    swiftui = "SwiftUI" in imports or re.search(r"^\s*import\s+SwiftUI\b", text, flags=re.MULTILINE)
    uikit = "UIKit" in imports or re.search(r"^\s*import\s+UIKit\b", text, flags=re.MULTILINE)

    if "/Views/" in rel or rel.endswith("View.swift") or rel.endswith("ViewModel.swift") or swiftui:
        return ROLE_UI

    if any(seg in rel for seg in ("/Composition/", "/AppGlue/", "/Adapter", "/Adapters/", "/Factories/", "/Factory")):
        return ROLE_UI_ADAPTER

    if owner in {"SafariLikeUIKit", "SafariLikeUXKit"}:
        return ROLE_UI_ADAPTER if uikit or swiftui else ROLE_INFRA

    if owner == "App":
        return ROLE_UI_ADAPTER

    # Default
    return ROLE_UI_ADAPTER


@dataclass(frozen=True)
class Policy:
    label: str
    allowed_internal: Set[str]
    forbidden_internal: Set[str]
    forbidden_apple: Set[str]


def policy_for(owner: str, role: str) -> Policy:
    # Keep these policies readable; the report links to violations, not perfect completeness.

    if role == ROLE_TEST:
        return Policy(
            label="Test/Example (must be outside Sources)",
            allowed_internal=set(INTERNAL_TOP_MODULES),
            forbidden_internal=set(),
            forbidden_apple=set(),
        )

    if role == ROLE_UI:
        return Policy(
            label="UI (SwiftUI/UIKit-only)",
            allowed_internal={"SafariLikeKit", "SafariLikeUXKit", "SafariLikeContracts"},
            forbidden_internal={"BrowserCore", "SafariLikeCoreKit"},
            forbidden_apple={"WebKit"},
        )

    if role == ROLE_UI_ADAPTER:
        # Adapters may touch BrowserCore (SSOT) but must not touch WebKit/CoreKit.
        return Policy(
            label="UI Adapter (no WebKit)",
            allowed_internal={"SafariLikeKit", "SafariLikeUXKit", "SafariLikeContracts", "BrowserCore"},
            forbidden_internal={"SafariLikeCoreKit"},
            forbidden_apple={"WebKit"},
        )

    if role == ROLE_DOMAIN:
        return Policy(
            label="Domain (UI-free)",
            allowed_internal={"SafariLikeContracts"},
            forbidden_internal={"SafariLikeKit", "SafariLikeUIKit", "SafariLikeUXKit", "SafariLikeCoreKit"},
            forbidden_apple={"SwiftUI", "UIKit", "WebKit"},
        )

    if role == ROLE_RUNTIME:
        return Policy(
            label="Runtime (WebKit/IO, UI-free)",
            allowed_internal={"SafariLikeContracts"},
            forbidden_internal={"SafariLikeKit", "SafariLikeUIKit", "SafariLikeUXKit", "BrowserCore"},
            forbidden_apple={"SwiftUI"},
        )

    # ROLE_INFRA
    return Policy(
        label="Infra/Policy/Diagnostics",
        allowed_internal={"SafariLikeContracts"},
        forbidden_internal={"SwiftUI", "UIKit", "WebKit"},
        forbidden_apple=set(),
    )


def in_production_sources(rel: str) -> bool:
    return "/Sources/" in rel or rel.startswith("App/")


def violations_for(rel: str, owner: str, role: str, imports: Sequence[str], text: str) -> List[str]:
    p = policy_for(owner, role)
    out: List[str] = []

    # 1) Test/example code in production sources
    if role == ROLE_TEST and in_production_sources(rel):
        out.append("Test/Example file present in production Sources")

    # 2) Forbidden internal module imports
    for imp in imports:
        if imp in p.forbidden_internal:
            out.append(f"Forbidden internal import: {imp} ({p.label})")

    # 3) Forbidden Apple modules
    for imp in imports:
        if imp in p.forbidden_apple:
            out.append(f"Forbidden Apple import: {imp} ({p.label})")

    # 4) Contracts should never import UI/web
    if owner == "SafariLikeContracts" and any(i in {"SwiftUI", "UIKit", "WebKit"} for i in imports):
        out.append("Contracts imports UI/WebKit")

    # 5) Global singleton usage heuristic
    if ".shared" in text or re.search(r"\bstatic\s+let\s+shared\b", text):
        # Avoid flagging common Apple singletons too loudly; keep as WARN.
        out.append("WARN: singleton usage heuristic (.shared/static shared)")

    return out


def render_csv_list(xs: Sequence[str]) -> str:
    if not xs:
        return "-"
    return ", ".join(xs)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="Docs/Architecture/Phase1/swift_file_inventory.md")
    ap.add_argument("--root", default=".")
    args = ap.parse_args()

    root = find_workspace_root(Path(args.root).resolve())
    out_path = (root / args.out).resolve()

    rows: List[Tuple[str, str, str, str, List[str]]] = []
    counts: dict[str, int] = {}
    violation_count = 0

    for path in sorted(iter_swift_files(root), key=lambda p: str(p)):
        rel = str(path.relative_to(root))
        text = read_text(path)
        imports = parse_imports(text)
        owner = owner_module_for(root, path)
        role = classify_role(rel, owner, imports, text)
        policy = policy_for(owner, role)
        vios = violations_for(rel, owner, role, imports, text)

        counts[role] = counts.get(role, 0) + 1
        if any(not v.startswith("WARN:") for v in vios):
            violation_count += 1

        rows.append(
            (
                rel,
                owner,
                role,
                f"{policy.label} | allow: {render_csv_list(sorted(policy.allowed_internal))} | forbid: {render_csv_list(sorted(policy.forbidden_internal | policy.forbidden_apple))}",
                imports,
                vios,
            )
        )

    out_path.parent.mkdir(parents=True, exist_ok=True)

    def esc(s: str) -> str:
        return s.replace("|", "\\|")

    with out_path.open("w", encoding="utf-8") as f:
        f.write("# Phase 1 — Full Swift File Inventory\n\n")
        f.write(f"Total Swift files: **{len(rows)}**\\n\\n")

        f.write("## Role counts\n\n")
        for k in sorted(counts.keys()):
            f.write(f"- {k}: {counts[k]}\\n")
        f.write("\n")

        f.write(f"Files with at least one non-WARN violation: **{violation_count}**\\n\n")

        f.write("## Inventory table\n\n")
        f.write("| File | Owner Module | Role | Allowed deps policy | Actual imports | Violations |\n")
        f.write("|---|---|---|---|---|---|\n")

        for rel, owner, role, policy_str, imports, vios in rows:
            f.write(
                "| {file} | {owner} | {role} | {policy} | {imports} | {vios} |\n".format(
                    file=esc(rel),
                    owner=esc(owner),
                    role=esc(role),
                    policy=esc(policy_str),
                    imports=esc(render_csv_list(imports)),
                    vios=esc("; ".join(vios) if vios else "-"),
                )
            )

    print(f"Wrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
