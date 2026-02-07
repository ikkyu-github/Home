#!/usr/bin/env python3
from __future__ import annotations

import hashlib
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Dupe:
    duplicate: Path
    canonical: Path
    digest: str


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    root = Path(".")

    canonical_files = sorted(
        (p for p in root.glob("RuntimePackages/**/Sources/**/*.swift") if p.is_file()),
        key=lambda p: p.as_posix(),
    )

    canonical_by_hash: dict[str, list[Path]] = {}
    for p in canonical_files:
        try:
            digest = sha256(p)
        except OSError:
            continue
        canonical_by_hash.setdefault(digest, []).append(p)

    candidates = sorted(
        (
            p
            for p in root.glob("**/*.swift")
            if p.is_file()
            and not ("RuntimePackages" in p.parts and "Sources" in p.parts)
        ),
        key=lambda p: p.as_posix(),
    )

    dupes: list[Dupe] = []
    for p in candidates:
        try:
            digest = sha256(p)
        except OSError:
            continue
        canon_list = canonical_by_hash.get(digest)
        if not canon_list:
            continue
        for canon in canon_list:
            dupes.append(Dupe(duplicate=p, canonical=canon, digest=digest))

    print(
        f"canonical_swift={len(canonical_files)} candidates={len(candidates)} duplicates={len(dupes)}"
    )

    # Print grouped by duplicate path
    by_dupe: dict[Path, list[Dupe]] = {}
    for d in dupes:
        by_dupe.setdefault(d.duplicate, []).append(d)

    for dup_path in sorted(by_dupe.keys(), key=lambda p: p.as_posix()):
        matches = by_dupe[dup_path]
        print(f"DUP {dup_path.as_posix()}")
        for m in matches:
            print(f"  == {m.canonical.as_posix()}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
