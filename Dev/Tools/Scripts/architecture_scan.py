#!/usr/bin/env python3
"""Phase 0 scanner (workspace-only).

Produces evidence-backed reports:
- Duplicate files by content hash (excluding build-like dirs)
- Zero-byte files
- Swift type name collisions across modules

This is intentionally conservative: it does not modify the repo.
"""

from __future__ import annotations

import argparse
import dataclasses
import hashlib
import os
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Iterable


IGNORE_DIR_NAMES = {
    ".git",
    "build",
    "DerivedData",
    "SourcePackages",
    "Carthage",
    "Pods",
    ".build",
    "node_modules",
    "xcuserdata",
    "xcshareddata",
}

TEXTY_SUFFIXES = {
    ".swift",
    ".md",
    ".sh",
    ".py",
    ".plist",
    ".json",
    ".strings",
    ".entitlements",
    ".pbxproj",
}

SWIFT_DECL_RE = re.compile(
    r"^(?:\s*(?:public|internal|private|fileprivate|open)\s+)?"  # access
    r"(?:\s*(?:final|indirect|actor)\s+)?"  # modifiers (subset)
    r"(struct|class|enum|protocol|actor|typealias)\s+([A-Za-z_][A-Za-z0-9_]*)\b",
    re.MULTILINE,
)


@dataclasses.dataclass(frozen=True)
class SwiftDecl:
    kind: str
    name: str
    file: str
    module: str


def iter_files(root: Path, *, max_bytes: int) -> Iterable[Path]:
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        # ignore by directory name anywhere in the path
        if any(part in IGNORE_DIR_NAMES for part in path.parts):
            continue
        try:
            size = path.stat().st_size
        except OSError:
            continue
        if size > max_bytes:
            continue
        yield path


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def guess_module(path: Path) -> str:
    # Heuristic: RuntimePackages/<Module>/Sources/... or App/... or Tools/... etc.
    parts = list(path.parts)
    if "RuntimePackages" in parts:
        i = parts.index("RuntimePackages")
        if i + 1 < len(parts):
            return parts[i + 1]
    if parts and parts[0] in {"App", "Tools", "Scripts", "Docs", "Dev"}:
        return parts[0]
    return "(root)"


def scan_duplicates(root: Path, *, max_bytes: int) -> dict[str, list[str]]:
    by_hash: dict[str, list[str]] = defaultdict(list)
    for p in iter_files(root, max_bytes=max_bytes):
        suffix = p.suffix.lower()
        if suffix and suffix not in TEXTY_SUFFIXES and "Assets.xcassets" not in str(p):
            continue
        try:
            digest = sha256(p)
        except Exception:
            continue
        by_hash[digest].append(str(p).lstrip("./"))

    return {h: paths for h, paths in by_hash.items() if len(paths) > 1}


def scan_zero_byte(root: Path) -> list[str]:
    out: list[str] = []
    for p in root.rglob("*"):
        if not p.is_file():
            continue
        if any(part in IGNORE_DIR_NAMES for part in p.parts):
            continue
        try:
            if p.stat().st_size == 0:
                out.append(str(p).lstrip("./"))
        except OSError:
            continue
    return sorted(out)


def scan_swift_decls(root: Path) -> list[SwiftDecl]:
    decls: list[SwiftDecl] = []
    for p in iter_files(root, max_bytes=5_000_000):
        if p.suffix.lower() != ".swift":
            continue
        try:
            text = p.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        module = guess_module(Path(str(p).lstrip("./")))
        rel = str(p).lstrip("./")
        for m in SWIFT_DECL_RE.finditer(text):
            kind, name = m.group(1), m.group(2)
            decls.append(SwiftDecl(kind=kind, name=name, file=rel, module=module))
    return decls


def build_type_collisions(decls: list[SwiftDecl]) -> dict[str, list[SwiftDecl]]:
    by_name: dict[str, list[SwiftDecl]] = defaultdict(list)
    for d in decls:
        by_name[d.name].append(d)

    collisions: dict[str, list[SwiftDecl]] = {}
    for name, items in by_name.items():
        modules = {d.module for d in items}
        if len(modules) > 1:
            collisions[name] = sorted(items, key=lambda d: (d.module, d.file, d.kind))
    return dict(sorted(collisions.items(), key=lambda kv: (-len({d.module for d in kv[1]}), kv[0])))


def write_report(
    *,
    root: Path,
    out_path: Path,
    duplicates: dict[str, list[str]],
    zero_byte: list[str],
    collisions: dict[str, list[SwiftDecl]],
) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)

    def w(s: str = ""):
        f.write(s + "\n")

    with out_path.open("w", encoding="utf-8") as f:
        w(f"# Phase 0 Scan Report")
        w()
        w(f"Root: `{root}`")
        w()

        w("## Zero-byte files (likely placeholders)")
        if not zero_byte:
            w("- (none)")
        else:
            for p in zero_byte:
                w(f"- {p}")
        w()

        w("## Duplicate files by content hash")
        if not duplicates:
            w("- (none)")
        else:
            # Show top groups by size (count)
            groups = sorted(duplicates.values(), key=lambda g: (-len(g), g[0]))
            for group in groups[:80]:
                w(f"- DUP ({len(group)} files):")
                for p in group:
                    w(f"  - {p}")
        w()

        w("## Swift type name collisions across modules")
        if not collisions:
            w("- (none)")
        else:
            for name, items in list(collisions.items())[:200]:
                modules = sorted({d.module for d in items})
                w(f"- `{name}` defined in modules: {', '.join(modules)}")
                for d in items:
                    w(f"  - {d.module}: {d.kind} in {d.file}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    ap.add_argument("--out", default="Docs/Architecture/phase0_scan_report.md")
    ap.add_argument("--max-bytes", type=int, default=20_000_000)
    args = ap.parse_args()

    root = Path(args.root).resolve()
    os.chdir(root)

    duplicates = scan_duplicates(Path("."), max_bytes=args.max_bytes)
    zero_byte = scan_zero_byte(Path("."))
    decls = scan_swift_decls(Path("."))
    collisions = build_type_collisions(decls)

    write_report(
        root=root,
        out_path=Path(args.out),
        duplicates=duplicates,
        zero_byte=zero_byte,
        collisions=collisions,
    )

    print(f"Wrote: {args.out}")
    print(f"Zero-byte: {len(zero_byte)}")
    print(f"Duplicate groups: {len(duplicates)}")
    print(f"Type collisions: {len(collisions)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
