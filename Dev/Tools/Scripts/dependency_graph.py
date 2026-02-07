#!/usr/bin/env python3
"""Generate a detailed dependency graph for this workspace.

Outputs:
- build_logs/dependency_graph.json
- build_logs/dependency_graph.md

Data sources:
- SwiftPM manifests (swift package dump-package)
- Real import edges by scanning Swift sources per target
- Xcode targets list (xcodebuild -list)

Notes:
- This script is best-effort and intentionally avoids heavy pbxproj parsing.
- It focuses on module boundaries and imports, which catch "boundary leaks".
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Set, Tuple

def find_workspace_root(start: Path) -> Path:
    """Find the workspace root by walking upward for known markers."""
    for p in [start] + list(start.parents):
        if (p / "RuntimePackages").exists() and (p / "App").exists():
            return p
        if (p / "RuntimePackages").exists() and (p / "webOS.xcodeproj").exists():
            return p
    return start


_SCRIPT_PATH = Path(__file__).resolve()
WORKSPACE_ROOT = find_workspace_root(Path.cwd())
if WORKSPACE_ROOT == Path.cwd() and not (WORKSPACE_ROOT / "RuntimePackages").exists():
    WORKSPACE_ROOT = find_workspace_root(_SCRIPT_PATH)
RUNTIME_PACKAGES = WORKSPACE_ROOT / "RuntimePackages"
OUTPUT_DIR = WORKSPACE_ROOT / "build_logs"

UI_FRAMEWORKS = {
    "SwiftUI",
    "UIKit",
    "WebKit",
    "AppKit",
    "WatchKit",
    "TVUIKit",
}

IMPORT_RE = re.compile(r"^\s*(?:@testable\s+)?import\s+([A-Za-z_][A-Za-z0-9_]*)\b")


@dataclass(frozen=True)
class ImportHit:
    file: str
    line: int
    imported: str
    raw: str


@dataclass
class TargetInfo:
    package: str
    target: str
    kind: str  # regular/test
    path: Path
    declared_target_deps: List[str]


def run(cmd: Sequence[str], cwd: Optional[Path] = None) -> str:
    proc = subprocess.run(
        list(cmd),
        cwd=str(cwd) if cwd else None,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            f"Command failed: {' '.join(cmd)}\n\nSTDOUT:\n{proc.stdout}\n\nSTDERR:\n{proc.stderr}"
        )
    return proc.stdout


def find_packages() -> List[Path]:
    if not RUNTIME_PACKAGES.exists():
        return []
    return sorted({p.parent for p in RUNTIME_PACKAGES.glob("*/Package.swift")})


def dump_package(package_dir: Path) -> dict:
    # Use `swift package dump-package` for stable JSON describing targets and dependencies.
    return json.loads(run(["swift", "package", "dump-package"], cwd=package_dir))


def parse_targets(package_dir: Path, dump: dict) -> List[TargetInfo]:
    package_name = dump.get("name") or package_dir.name
    targets: List[TargetInfo] = []

    for t in dump.get("targets", []):
        name = t.get("name")
        ttype = t.get("type")
        kind = "test" if ttype == "test" else "regular"

        raw_path = t.get("path")
        if raw_path:
            source_dir = (package_dir / raw_path).resolve()
        else:
            # Conventional layout.
            source_dir = (package_dir / ("Tests" if kind == "test" else "Sources") / name).resolve()

        deps: List[str] = []
        for dep in t.get("dependencies", []):
            # Each dependency is a dict with one key.
            if isinstance(dep, dict) and "target" in dep and isinstance(dep["target"], list):
                # {"target": ["BrowserCore", null]}
                dep_name = dep["target"][0]
                if isinstance(dep_name, str):
                    deps.append(dep_name)
            elif isinstance(dep, dict) and "product" in dep and isinstance(dep["product"], list):
                # {"product": ["BrowserCore", "BrowserCore"]} or external products like Logging.
                product_name = dep["product"][0]
                if isinstance(product_name, str):
                    deps.append(product_name)

        targets.append(
            TargetInfo(
                package=package_name,
                target=name,
                kind=kind,
                path=source_dir,
                declared_target_deps=sorted(set(deps)),
            )
        )

    return targets


def iter_swift_files(root: Path) -> Iterable[Path]:
    if not root.exists():
        return
    for p in root.rglob("*.swift"):
        if "/.build/" in str(p):
            continue
        yield p


def scan_imports(swift_file: Path) -> List[Tuple[int, str, str]]:
    hits: List[Tuple[int, str, str]] = []
    try:
        text = swift_file.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        text = swift_file.read_text(encoding="utf-8", errors="ignore")

    for idx, raw in enumerate(text.splitlines(), start=1):
        m = IMPORT_RE.match(raw)
        if not m:
            continue
        imported = m.group(1)
        hits.append((idx, imported, raw.strip()))

    return hits


def find_cycles(edges: Dict[str, Set[str]]) -> List[List[str]]:
    visited: Set[str] = set()
    stack: List[str] = []
    on_stack: Set[str] = set()
    cycles: List[List[str]] = []

    def dfs(n: str):
        visited.add(n)
        stack.append(n)
        on_stack.add(n)
        for m in sorted(edges.get(n, set())):
            if m not in visited:
                dfs(m)
            elif m in on_stack:
                # cycle found; slice stack
                try:
                    i = stack.index(m)
                    cyc = stack[i:] + [m]
                    # normalize (rotate to smallest)
                    # keep unique by string key
                    cycles.append(cyc)
                except ValueError:
                    pass
        stack.pop()
        on_stack.remove(n)

    for node in sorted(edges.keys()):
        if node not in visited:
            dfs(node)

    # Deduplicate cycles
    uniq: Dict[str, List[str]] = {}
    for cyc in cycles:
        key = "->".join(cyc)
        uniq[key] = cyc
    return list(uniq.values())


def classify_layer(module: str) -> str:
    # Simple, explicit classification used for policy checks.
    if module == "SafariLikeContracts":
        return "Contracts"
    if module in {"BrowserCore", "SafariLikeCoreKit", "SafariLikeUXKit"}:
        return "Core"
    if module in {"SafariLikeKit", "SafariLikeBuiltinPlugins"}:
        return "UI"
    if module in {"SafariLikeUIKit"}:
        return "Platform"
    # Unknown / app target / others.
    return "App/Other"


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    packages = find_packages()

    # Collect SwiftPM targets
    targets: List[TargetInfo] = []
    package_dumps: Dict[str, dict] = {}
    for pkg_dir in packages:
        dump = dump_package(pkg_dir)
        package_dumps[pkg_dir.name] = dump
        targets.extend(parse_targets(pkg_dir, dump))

    internal_modules: Set[str] = {t.target for t in targets if t.kind == "regular"}

    # Build declared edges (target dependencies in manifests)
    declared_edges: Dict[str, Set[str]] = {m: set() for m in sorted(internal_modules)}
    target_by_name: Dict[str, TargetInfo] = {t.target: t for t in targets if t.kind == "regular"}
    for t in targets:
        if t.kind != "regular":
            continue
        for dep in t.declared_target_deps:
            if dep in internal_modules:
                declared_edges[t.target].add(dep)

    # Build import edges + record import hits
    import_edges: Dict[str, Set[str]] = {m: set() for m in sorted(internal_modules)}
    import_hits: Dict[str, List[ImportHit]] = {m: [] for m in sorted(internal_modules)}
    external_imports: Dict[str, Set[str]] = {m: set() for m in sorted(internal_modules)}

    for module in sorted(internal_modules):
        t = target_by_name.get(module)
        if not t:
            continue
        for f in iter_swift_files(t.path):
            rel = str(f.relative_to(WORKSPACE_ROOT))
            for line_no, imported, raw in scan_imports(f):
                if imported in internal_modules:
                    import_edges[module].add(imported)
                    import_hits[module].append(
                        ImportHit(file=rel, line=line_no, imported=imported, raw=raw)
                    )
                else:
                    external_imports[module].add(imported)

    # Cycles
    cycles_declared = find_cycles(declared_edges)
    cycles_import = find_cycles(import_edges)

    # Violations
    violations: List[dict] = []

    def add_violation(
        rule: str,
        module: str,
        imported: str,
        hit: ImportHit,
        severity: str,
    ):
        violations.append(
            {
                "rule": rule,
                "severity": severity,
                "module": module,
                "imported": imported,
                "file": hit.file,
                "line": hit.line,
                "import": hit.raw,
            }
        )

    # Rule: SafariLikeContracts must not depend on UI frameworks or UI/Kit layers.
    if "SafariLikeContracts" in internal_modules:
        for hit in import_hits["SafariLikeContracts"]:
            if hit.imported in UI_FRAMEWORKS:
                add_violation(
                    rule="SafariLikeContracts.bottom_layer_no_UI_frameworks",
                    module="SafariLikeContracts",
                    imported=hit.imported,
                    hit=hit,
                    severity="error",
                )
            if hit.imported in {"SafariLikeKit", "SafariLikeUIKit"}:
                add_violation(
                    rule="SafariLikeContracts.bottom_layer_no_UI_modules",
                    module="SafariLikeContracts",
                    imported=hit.imported,
                    hit=hit,
                    severity="error",
                )

    # Rule: BrowserCore must not import UI frameworks.
    if "BrowserCore" in internal_modules:
        for hit in import_hits["BrowserCore"]:
            if hit.imported in UI_FRAMEWORKS:
                add_violation(
                    rule="BrowserCore.no_UI_frameworks",
                    module="BrowserCore",
                    imported=hit.imported,
                    hit=hit,
                    severity="error",
                )

    # Layer boundary checks.
    # Convention used here:
    #   UI/Platform can depend on Core/Contracts
    #   Core can depend on Contracts
    #   Contracts depends on nothing internal
    # I.e. dependencies should point "down" to lower layers.
    layer_order = {
        "Contracts": 0,
        "Core": 1,
        "Platform": 2,
        "UI": 3,
        "App/Other": 4,
    }

    def layer_index(m: str) -> int:
        return layer_order.get(classify_layer(m), 99)

    for module in sorted(internal_modules):
        src_i = layer_index(module)
        for dep in sorted(import_edges.get(module, set())):
            dst_i = layer_index(dep)

            # Allowed direction: higher/equal layer imports lower/equal.
            # Violation: lower layer imports higher layer.
            if src_i < dst_i:
                for hit in import_hits[module]:
                    if hit.imported == dep:
                        add_violation(
                            rule="Layering.lower_layer_imports_higher_layer",
                            module=module,
                            imported=dep,
                            hit=hit,
                            severity="error",
                        )
                        break

    # Rule: SafariLikeKit (UI) should call Core via Contracts, not import Core modules directly.
    # SafariLikeUXKit is treated as UI-facing policy/UX surface and is allowed.
    for ui_module in [m for m in internal_modules if classify_layer(m) == "UI"]:
        for hit in import_hits[ui_module]:
            if hit.imported in {"BrowserCore", "SafariLikeCoreKit"}:
                add_violation(
                    rule="UI.should_not_import_Core_directly_use_Contracts",
                    module=ui_module,
                    imported=hit.imported,
                    hit=hit,
                    severity="error",
                )

    # Rule: SafariLikeContracts bottom layer must not import any internal module (except itself)
    # and must not import UI frameworks.
    if "SafariLikeContracts" in internal_modules:
        for hit in import_hits["SafariLikeContracts"]:
            if hit.imported in UI_FRAMEWORKS:
                add_violation(
                    rule="SafariLikeContracts.bottom_layer_no_UI_frameworks",
                    module="SafariLikeContracts",
                    imported=hit.imported,
                    hit=hit,
                    severity="error",
                )
            elif hit.imported in internal_modules and hit.imported != "SafariLikeContracts":
                add_violation(
                    rule="SafariLikeContracts.bottom_layer_no_internal_module_imports",
                    module="SafariLikeContracts",
                    imported=hit.imported,
                    hit=hit,
                    severity="error",
                )

    # Prepare outputs
    report = {
        "generatedAt": str(date.today()),
        "workspaceRoot": str(WORKSPACE_ROOT),
        "swiftPackages": [str(p.relative_to(WORKSPACE_ROOT)) for p in packages],
        "modules": sorted(internal_modules),
        "targets": [
            {
                "package": t.package,
                "target": t.target,
                "kind": t.kind,
                "path": str(t.path.relative_to(WORKSPACE_ROOT)) if t.path.exists() else str(t.path),
                "declaredTargetDependencies": t.declared_target_deps,
            }
            for t in targets
        ],
        "declaredEdges": {k: sorted(v) for k, v in declared_edges.items()},
        "importEdges": {k: sorted(v) for k, v in import_edges.items()},
        "externalImports": {k: sorted(v) for k, v in external_imports.items()},
        "cycles": {
            "declared": cycles_declared,
            "imports": cycles_import,
        },
        "violations": violations,
        "layers": {
            "Contracts": [m for m in sorted(internal_modules) if classify_layer(m) == "Contracts"],
            "Core": [m for m in sorted(internal_modules) if classify_layer(m) == "Core"],
            "Platform": [m for m in sorted(internal_modules) if classify_layer(m) == "Platform"],
            "UI": [m for m in sorted(internal_modules) if classify_layer(m) == "UI"],
            "App/Other": [m for m in sorted(internal_modules) if classify_layer(m) == "App/Other"],
        },
    }

    json_path = OUTPUT_DIR / "dependency_graph.json"
    json_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    # Markdown summary
    md_lines: List[str] = []
    md_lines.append(f"# Dependency Graph (generated {report['generatedAt']})")
    md_lines.append("")
    md_lines.append("## Modules")
    for m in report["modules"]:
        md_lines.append(f"- {m} ({classify_layer(m)})")
    md_lines.append("")

    md_lines.append("## Graph (Declared Target Dependencies)")
    for src in sorted(declared_edges.keys()):
        for dst in sorted(declared_edges[src]):
            md_lines.append(f"- {src} -> {dst}")
    md_lines.append("")

    md_lines.append("## Graph (Observed Imports)")
    for src in sorted(import_edges.keys()):
        for dst in sorted(import_edges[src]):
            md_lines.append(f"- {src} -> {dst}")
    md_lines.append("")

    md_lines.append("## Layered Map")
    for layer in ["Contracts", "Core", "Platform", "UI", "App/Other"]:
        md_lines.append(f"### {layer}")
        for m in report["layers"][layer]:
            md_lines.append(f"- {m}")
        md_lines.append("")

    md_lines.append("## Cycles")
    md_lines.append("### Declared")
    if cycles_declared:
        for c in cycles_declared:
            md_lines.append(f"- {' -> '.join(c)}")
    else:
        md_lines.append("- (none)")
    md_lines.append("")
    md_lines.append("### Imports")
    if cycles_import:
        for c in cycles_import:
            md_lines.append(f"- {' -> '.join(c)}")
    else:
        md_lines.append("- (none)")
    md_lines.append("")

    md_lines.append("## Violations")
    if violations:
        for v in violations:
            md_lines.append(
                f"- [{v['severity']}] {v['rule']}: {v['module']} imports {v['imported']} @ {v['file']}:{v['line']} ({v['import']})"
            )
    else:
        md_lines.append("- (none)")
    md_lines.append("")

    md_path = OUTPUT_DIR / "dependency_graph.md"
    md_path.write_text("\n".join(md_lines) + "\n", encoding="utf-8")

    print(f"Wrote {json_path}")
    print(f"Wrote {md_path}")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        print(str(e), file=sys.stderr)
        raise
