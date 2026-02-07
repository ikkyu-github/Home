#!/usr/bin/env python3
"""Dead code / unused file / placeholder audit for this repo.

This is a deterministic, build-aware audit:
- "Unused file" is defined as a .swift file that is not compiled by any SwiftPM target
  (RuntimePackages/*) AND not compiled by any Xcode target (PBXSourcesBuildPhase).
- "Placeholder/stub" is based on explicit markers in file content.
- "Unused type/function" is best-effort using workspace-wide token occurrence counts.

Outputs:
- build_logs/dead_code_report.json
- build_logs/dead_code_report.md
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Set, Tuple

WORKSPACE_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_PACKAGES = WORKSPACE_ROOT / "RuntimePackages"
OUTPUT_DIR = WORKSPACE_ROOT / "build_logs"
PBXPROJ = WORKSPACE_ROOT / "webOS.xcodeproj" / "project.pbxproj"

EXCLUDE_DIR_PARTS = {
    "/build/",
    "/.build/",
    "/DerivedData/",
    "/build_logs/",
}

STUB_MARKERS = [
    "Intentionally left as a stub",
    "placeholder to keep indexing happy",
    "Placeholder:",
    "// Placeholder",
    "TODO:",
    "FIXME",
    "not implemented",
]

DECL_TYPE_RE = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*"
    r"(?:public|internal|private|fileprivate|open)?\s*"
    r"(?:final\s+)?"
    r"(class|struct|enum|protocol|actor)\s+([A-Za-z_][A-Za-z0-9_]*)\b"
)

DECL_FUNC_RE = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*"
    r"(?:public|internal|private|fileprivate|open)?\s*"
    r"(?:static\s+|class\s+)?"
    r"func\s+([A-Za-z_][A-Za-z0-9_]*)\b"
)


@dataclass(frozen=True)
class Decl:
    kind: str  # type|func
    name: str
    file: str
    line: int


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


def iter_swift_files(root: Path) -> Iterable[Path]:
    for p in root.rglob("*.swift"):
        ps = str(p)
        if any(part in ps for part in EXCLUDE_DIR_PARTS):
            continue
        # SwiftPM manifest is not a source file.
        if p.name == "Package.swift" and "RuntimePackages" in ps:
            continue
        yield p


def find_packages() -> List[Path]:
    if not RUNTIME_PACKAGES.exists():
        return []
    return sorted({p.parent for p in RUNTIME_PACKAGES.glob("*/Package.swift")})


def dump_package(package_dir: Path) -> dict:
    return json.loads(run(["swift", "package", "dump-package"], cwd=package_dir))


def swiftpm_compiled_files(*, include_tests: bool) -> Set[str]:
    compiled: Set[str] = set()
    for pkg_dir in find_packages():
        dump = dump_package(pkg_dir)
        for t in dump.get("targets", []):
            if (t.get("type") == "test") and not include_tests:
                continue
            name = t.get("name")
            raw_path = t.get("path")
            if raw_path:
                src_dir = (pkg_dir / raw_path).resolve()
            else:
                src_dir = (pkg_dir / "Sources" / name).resolve()
            if not src_dir.exists():
                continue
            for f in iter_swift_files(src_dir):
                compiled.add(str(f.relative_to(WORKSPACE_ROOT)))
    return compiled


def _extract_section(text: str, begin: str, end: str) -> str:
    bi = text.find(begin)
    ei = text.find(end)
    if bi == -1 or ei == -1 or ei <= bi:
        return ""
    return text[bi + len(begin) : ei]


def xcode_compiled_files() -> Set[str]:
    if not PBXPROJ.exists():
        return set()

    text = PBXPROJ.read_text(encoding="utf-8", errors="ignore")

    file_ref_section = _extract_section(
        text,
        "/* Begin PBXFileReference section */",
        "/* End PBXFileReference section */",
    )
    group_section = _extract_section(
        text,
        "/* Begin PBXGroup section */",
        "/* End PBXGroup section */",
    )
    build_file_section = _extract_section(
        text,
        "/* Begin PBXBuildFile section */",
        "/* End PBXBuildFile section */",
    )
    sources_phase_section = _extract_section(
        text,
        "/* Begin PBXSourcesBuildPhase section */",
        "/* End PBXSourcesBuildPhase section */",
    )

    # PBXFileReference: id -> (path, name)
    file_ref_to_path: Dict[str, str] = {}
    file_ref_to_name: Dict[str, str] = {}
    for m in re.finditer(
        r"(?m)^\s*([A-F0-9]{24})\s*/\*.*?\*/\s*=\s*\{[^}]*?\bpath\s*=\s*(?:\"([^\"]+)\"|([^;]+));",
        file_ref_section,
    ):
        ref_id = m.group(1)
        path = (m.group(2) or m.group(3) or "").strip().strip('"')
        if path.endswith(".swift"):
            file_ref_to_path[ref_id] = path

    for m in re.finditer(
        r"(?m)^\s*([A-F0-9]{24})\s*/\*\s*([^*]+?)\s*\*/\s*=\s*\{[^}]*?isa\s*=\s*PBXFileReference;",
        file_ref_section,
    ):
        file_ref_to_name[m.group(1)] = m.group(2).strip()

    # PBXGroup: build parent map and group path segments
    group_to_path: Dict[str, str] = {}
    child_to_parent: Dict[str, str] = {}
    for gm in re.finditer(
        r"(?ms)^\s*([A-F0-9]{24})\s*/\*\s*([^*]+?)\s*\*/\s*=\s*\{\s*isa\s*=\s*PBXGroup;.*?\};",
        group_section,
    ):
        gid = gm.group(1)
        block = gm.group(0)

        pm = re.search(r"(?m)^\s*path\s*=\s*(?:\"([^\"]+)\"|([^;]+));", block)
        if pm:
            path = (pm.group(1) or pm.group(2) or "").strip().strip('"')
            if path:
                group_to_path[gid] = path

        cm = re.search(r"(?ms)\bchildren\s*=\s*\((.*?)\);", block)
        if cm:
            for idm in re.finditer(r"\b([A-F0-9]{24})\b", cm.group(1)):
                child_to_parent[idm.group(1)] = gid

    def resolve_group_folder(child_id: str) -> Optional[Path]:
        # Walk up parent groups collecting `path` segments.
        segs: List[str] = []
        cur = child_to_parent.get(child_id)
        seen: Set[str] = set()
        while cur and cur not in seen:
            seen.add(cur)
            p = group_to_path.get(cur)
            if p and p not in {"<group>", ""}:
                segs.append(p)
            cur = child_to_parent.get(cur)
        if not segs:
            return None
        return Path(*reversed(segs))

    # PBXBuildFile: buildFile id -> fileRef id (allow nested braces in settings)
    build_file_to_ref: Dict[str, str] = {}
    for m in re.finditer(
        r"(?ms)^\s*([A-F0-9]{24})\s*/\*.*?\*/\s*=\s*\{.*?\bfileRef\s*=\s*([A-F0-9]{24})\b.*?\};",
        build_file_section,
    ):
        build_file_to_ref[m.group(1)] = m.group(2)

    # PBXSourcesBuildPhase: gather buildFile ids listed under files = (...)
    source_build_file_ids: Set[str] = set()
    for phase_match in re.finditer(
        r"(?ms)\bfiles\s*=\s*\((.*?)\);",
        sources_phase_section,
    ):
        body = phase_match.group(1)
        for id_match in re.finditer(r"\b([A-F0-9]{24})\b", body):
            source_build_file_ids.add(id_match.group(1))

    compiled: Set[str] = set()
    for build_id in source_build_file_ids:
        ref_id = build_file_to_ref.get(build_id)
        if not ref_id:
            continue
        raw_path = file_ref_to_path.get(ref_id)
        name = file_ref_to_name.get(ref_id)
        if not raw_path and name and name.endswith(".swift"):
            raw_path = name
        candidate_paths: List[Path] = []
        if raw_path:
            candidate_paths.append((WORKSPACE_ROOT / raw_path).resolve())
        if name and name.endswith(".swift") and (not raw_path or (WORKSPACE_ROOT / raw_path).name != name):
            candidate_paths.append((WORKSPACE_ROOT / name).resolve())

        # If pbxproj stores only a basename, try to resolve via group folder.
        if raw_path:
            folder = resolve_group_folder(ref_id)
            if folder:
                candidate_paths.append((WORKSPACE_ROOT / folder / Path(raw_path).name).resolve())

        resolved: Optional[Path] = None
        for c in candidate_paths:
            if c.exists() and c.suffix == ".swift":
                resolved = c
                break

        if not resolved:
            # Fallback: basename-only path is common in pbxproj; resolve uniquely in repo.
            base = None
            if raw_path and raw_path.endswith(".swift"):
                base = Path(raw_path).name
            elif name and name.endswith(".swift"):
                base = Path(name).name

            if base:
                matches = [p for p in iter_swift_files(WORKSPACE_ROOT) if p.name == base]
                if len(matches) == 1:
                    resolved = matches[0]

        if resolved:
            compiled.add(str(resolved.relative_to(WORKSPACE_ROOT)))

    return compiled


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8", errors="ignore")


def is_stub(text: str) -> Tuple[bool, List[str]]:
    reasons: List[str] = []
    for m in STUB_MARKERS:
        if m in text:
            reasons.append(m)
    if "fatalError(" in text or "preconditionFailure(" in text:
        reasons.append("fatalError/preconditionFailure")

    # Very small files that are basically empty/comment-only
    lines = [ln.rstrip() for ln in text.splitlines()]
    non_empty = [ln for ln in lines if ln.strip()]
    codeish = [ln for ln in non_empty if not ln.strip().startswith("//")]
    if len(codeish) <= 2 and len(lines) <= 25:
        reasons.append("mostly-empty")

    return (len(reasons) > 0, sorted(set(reasons)))


def extract_decls(path: Path) -> List[Decl]:
    text = read_text(path)
    decls: List[Decl] = []
    for i, line in enumerate(text.splitlines(), start=1):
        m = DECL_TYPE_RE.match(line)
        if m:
            decls.append(Decl(kind="type", name=m.group(2), file=str(path.relative_to(WORKSPACE_ROOT)), line=i))
            continue
        m2 = DECL_FUNC_RE.match(line)
        if m2:
            fn = m2.group(1)
            if fn in {"init", "deinit"}:
                continue
            decls.append(Decl(kind="func", name=fn, file=str(path.relative_to(WORKSPACE_ROOT)), line=i))
    return decls


def build_token_index(all_swift_files: List[Path]) -> Dict[str, int]:
    # Best-effort token frequency across all swift files.
    freq: Dict[str, int] = {}
    word_re = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]*\b")
    for f in all_swift_files:
        text = read_text(f)
        for w in word_re.findall(text):
            freq[w] = freq.get(w, 0) + 1
    return freq


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    all_files = sorted(iter_swift_files(WORKSPACE_ROOT))
    all_rel = [str(p.relative_to(WORKSPACE_ROOT)) for p in all_files]

    swiftpm_files = swiftpm_compiled_files(include_tests=False)
    swiftpm_test_files = swiftpm_compiled_files(include_tests=True) - swiftpm_files
    xcode_files = xcode_compiled_files()

    compiled = swiftpm_files | xcode_files
    # Treat test sources as "used" (compiled under swift test) even if not in the main build.
    not_compiled = sorted([p for p in all_rel if p not in compiled and p not in swiftpm_test_files])

    stub_files: List[dict] = []
    for rel in all_rel:
        p = WORKSPACE_ROOT / rel
        text = read_text(p)
        stub, reasons = is_stub(text)
        if stub:
            stub_files.append(
                {
                    "file": rel,
                    "compiledBy": (
                        "both" if (rel in swiftpm_files and rel in xcode_files) else "swiftpm" if rel in swiftpm_files else "xcode" if rel in xcode_files else "none"
                    ),
                    "reasons": reasons,
                }
            )

    # Candidate unused decls (compiled files only)
    compiled_paths = [WORKSPACE_ROOT / rel for rel in sorted(compiled) if (WORKSPACE_ROOT / rel).exists()]
    decls: List[Decl] = []
    for p in compiled_paths:
        decls.extend(extract_decls(p))

    token_freq = build_token_index(all_files)

    unused_candidates: List[dict] = []
    for d in decls:
        # A declaration will contribute at least 1 occurrence.
        occ = token_freq.get(d.name, 0)
        if occ <= 1:
            unused_candidates.append(
                {
                    "kind": d.kind,
                    "name": d.name,
                    "file": d.file,
                    "line": d.line,
                    "occurrences": occ,
                }
            )

    # Grouping A/B/C for files
    group_A: List[dict] = []
    group_B: List[dict] = []
    group_C: List[dict] = []

    stub_set = {s["file"] for s in stub_files}

    for rel in not_compiled:
        entry = {
            "file": rel,
            "reason": "Not compiled by SwiftPM targets or Xcode PBXSourcesBuildPhase",
            "buildImpact": "No build impact (file not in any compile sources list)",
        }
        # Heuristic for immediate delete: clearly legacy/archive.
        if rel.startswith("Dev/") or "/Archive/" in rel or "_legacy" in rel:
            group_A.append(entry)
        else:
            group_B.append(entry)

    for s in stub_files:
        rel = s["file"]
        entry = {
            "file": rel,
            "reason": f"Placeholder/stub markers: {', '.join(s['reasons'])}",
            "compiledBy": s["compiledBy"],
            "buildImpact": "If compiled: remains in binary; if not compiled: no build impact",
        }
        if s["compiledBy"] == "none":
            # Non-compiled stub: safe delete if legacy; otherwise review.
            if rel.startswith("Dev/") or "/Archive/" in rel or "_legacy" in rel:
                group_A.append(entry)
            else:
                group_B.append(entry)
        else:
            group_C.append(entry)

    report = {
        "generatedAt": str(date.today()),
        "workspaceRoot": str(WORKSPACE_ROOT),
        "counts": {
            "swiftFilesTotal": len(all_rel),
            "compiledBySwiftPM": len(swiftpm_files),
            "compiledByXcode": len(xcode_files),
            "compiledUnion": len(compiled),
            "notCompiled": len(not_compiled),
            "stubFiles": len(stub_files),
            "unusedSymbolCandidates": len(unused_candidates),
        },
        "compiled": {
            "swiftpm": sorted(swiftpm_files),
            "swiftpmTests": sorted(swiftpm_test_files),
            "xcode": sorted(xcode_files),
        },
        "groups": {
            "A_delete_now": sorted(group_A, key=lambda x: x["file"]),
            "B_move_or_review": sorted(group_B, key=lambda x: x["file"]),
            "C_implement_or_remove": sorted(group_C, key=lambda x: x["file"]),
        },
        "stubFiles": sorted(stub_files, key=lambda x: x["file"]),
        "unusedSymbolCandidates": sorted(unused_candidates, key=lambda x: (x["kind"], x["name"]))[:200],
    }

    json_path = OUTPUT_DIR / "dead_code_report.json"
    json_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    # Markdown summary
    md: List[str] = []
    md.append(f"# Dead Code / Unused Files / Placeholder (generated {report['generatedAt']})")
    md.append("")
    c = report["counts"]
    md.append("## Counts")
    md.append(f"- swiftFilesTotal: {c['swiftFilesTotal']}")
    md.append(f"- compiledUnion: {c['compiledUnion']} (SwiftPM {c['compiledBySwiftPM']}, Xcode {c['compiledByXcode']})")
    md.append(f"- notCompiled: {c['notCompiled']}")
    md.append(f"- stubFiles: {c['stubFiles']}")
    md.append(f"- unusedSymbolCandidates (top 200): {c['unusedSymbolCandidates']}")
    md.append("")

    def render_group(title: str, items: List[dict]):
        md.append(f"## {title}")
        if not items:
            md.append("- (none)")
            md.append("")
            return
        for it in items:
            line = f"- {it['file']} — {it.get('reason','')}"
            if "compiledBy" in it:
                line += f" — compiledBy={it['compiledBy']}"
            md.append(line)
        md.append("")

    render_group("A) Delete Immediately (build-safe)", report["groups"]["A_delete_now"])
    render_group("B) Move/Review", report["groups"]["B_move_or_review"])
    render_group("C) Implement or Remove (compiled stubs)", report["groups"]["C_implement_or_remove"])

    md.append("## Unused Symbol Candidates (top 200, occurrence<=1)")
    for u in report["unusedSymbolCandidates"]:
        md.append(f"- {u['kind']} {u['name']} @ {u['file']}:{u['line']} (occurrences={u['occurrences']})")
    md.append("")

    md_path = OUTPUT_DIR / "dead_code_report.md"
    md_path.write_text("\n".join(md) + "\n", encoding="utf-8")

    print(f"Wrote {json_path}")
    print(f"Wrote {md_path}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        print(str(e), file=sys.stderr)
        raise
