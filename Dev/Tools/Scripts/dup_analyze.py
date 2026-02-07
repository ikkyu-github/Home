#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import os
import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


DEFAULT_EXCLUDE_DIRS = {
    ".git",
    "build",
    "DerivedData",
    ".swiftpm",
    ".vscode",
    "Dev/PBXBackups",
    "Dev/_orphaned",
}


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def iter_files(root: Path, *, patterns: list[str], exclude_dirs: set[str]) -> Iterable[Path]:
    for pattern in patterns:
        for p in root.rglob(pattern):
            if not p.is_file():
                continue
            if is_excluded(p, root=root, exclude_dirs=exclude_dirs):
                continue
            # Drop most Dev backups; keep Dev/Tests + Dev/Tools
            rel = p.relative_to(root).as_posix()
            if rel.startswith("Dev/") and not (rel.startswith("Dev/Tests/") or rel.startswith("Dev/Tools/")):
                continue
            yield p


def is_excluded(path: Path, *, root: Path, exclude_dirs: set[str]) -> bool:
    rel = path.relative_to(root)
    parts = rel.parts
    if ".build" in parts:
        return True

    s = rel.as_posix()
    for d in exclude_dirs:
        if s == d or s.startswith(d + "/"):
            return True
    return False


COMMENT_BLOCK_RE = re.compile(r"/\*.*?\*/", re.DOTALL)
COMMENT_LINE_RE = re.compile(r"//.*$")


def normalize_swift_for_similarity(text: str) -> str:
    # Remove block comments and line comments, normalize whitespace.
    text = COMMENT_BLOCK_RE.sub("", text)
    text = "\n".join(COMMENT_LINE_RE.sub("", line) for line in text.splitlines())
    text = re.sub(r"\s+", " ", text).strip()
    return text


def shingle_hashes(text: str, *, k: int = 9) -> set[int]:
    # k-word shingles (after normalization). Hash to int.
    words = text.split()
    if len(words) < k:
        return set()
    out: set[int] = set()
    for i in range(0, len(words) - k + 1):
        sh = " ".join(words[i : i + k]).encode("utf-8", errors="ignore")
        out.add(int(hashlib.blake2b(sh, digest_size=8).hexdigest(), 16))
    return out


def jaccard(a: set[int], b: set[int]) -> float:
    if not a or not b:
        return 0.0
    inter = len(a & b)
    union = len(a | b)
    return inter / union if union else 0.0


@dataclass(frozen=True)
class SimilarPair:
    a: Path
    b: Path
    score: float


def main() -> int:
    ap = argparse.ArgumentParser(description="Analyze duplicate/similar files and copy-paste blocks.")
    ap.add_argument("--root", default=".")
    ap.add_argument("--min-jaccard", type=float, default=0.75, help="Similarity threshold for same-basename file pairs")
    ap.add_argument("--min-block-lines", type=int, default=18, help="Minimum line-block size to consider a clone")
    ap.add_argument("--max-block-hits", type=int, default=12, help="Limit printed hits per clone block")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    exclude_dirs = set(DEFAULT_EXCLUDE_DIRS)

    swift_files = sorted(set(iter_files(root, patterns=["*.swift"], exclude_dirs=exclude_dirs)))

    # 1) Exact duplicates (byte-identical)
    by_hash: dict[str, list[Path]] = defaultdict(list)
    for p in swift_files:
        by_hash[sha256_bytes(p.read_bytes())].append(p)
    exact_groups = [ps for ps in by_hash.values() if len(ps) > 1]
    exact_groups.sort(key=lambda g: (-len(g), str(g[0])))

    # 2) Same basename (potentially similar)
    by_name: dict[str, list[Path]] = defaultdict(list)
    for p in swift_files:
        by_name[p.name].append(p)
    basename_groups = {n: ps for n, ps in by_name.items() if len(ps) > 1}

    # 3) Similarity among same-basename files
    similar_pairs: list[SimilarPair] = []
    for name, paths in sorted(basename_groups.items()):
        normalized: dict[Path, str] = {}
        shingles: dict[Path, set[int]] = {}
        for p in paths:
            txt = p.read_text(encoding="utf-8", errors="ignore")
            n = normalize_swift_for_similarity(txt)
            normalized[p] = n
            shingles[p] = shingle_hashes(n)
        for i in range(len(paths)):
            for j in range(i + 1, len(paths)):
                a, b = paths[i], paths[j]
                score = jaccard(shingles[a], shingles[b])
                if score >= args.min_jaccard:
                    similar_pairs.append(SimilarPair(a=a, b=b, score=score))
    similar_pairs.sort(key=lambda sp: (-sp.score, str(sp.a), str(sp.b)))

    # 4) Copy-paste blocks: rolling hash of normalized line windows
    # Normalize lines lightly (strip leading/trailing whitespace and collapse multiple spaces).
    def norm_line(line: str) -> str:
        line = COMMENT_LINE_RE.sub("", line)
        line = line.strip()
        line = re.sub(r"\s+", " ", line)
        return line

    block_n = max(5, int(args.min_block_lines))
    block_map: dict[str, list[tuple[Path, int]]] = defaultdict(list)

    for p in swift_files:
        lines = p.read_text(encoding="utf-8", errors="ignore").splitlines()
        nlines = [norm_line(l) for l in lines]
        # drop empty lines for hashing windows, but keep indices mapping
        filtered: list[tuple[int, str]] = [(idx, l) for idx, l in enumerate(nlines) if l]
        if len(filtered) < block_n:
            continue
        for i in range(0, len(filtered) - block_n + 1):
            start_idx = filtered[i][0]
            window = "\n".join(l for _, l in filtered[i : i + block_n])
            h = hashlib.blake2b(window.encode("utf-8", errors="ignore"), digest_size=16).hexdigest()
            block_map[h].append((p, start_idx))

    clone_blocks = [(h, locs) for h, locs in block_map.items() if len({(p, i) for p, i in locs}) > 1]
    # Prefer blocks that span multiple files
    clone_blocks.sort(key=lambda kv: (-len({p for p, _ in kv[1]}), -len(kv[1]), kv[0]))

    print(f"ROOT {root}")
    print(f"SWIFT_FILES {len(swift_files)}")

    print(f"\nEXACT_DUP_GROUPS {len(exact_groups)}")
    for group in exact_groups:
        h = sha256_bytes(group[0].read_bytes())[:12]
        print(f"\n== exact dup sha256={h} x{len(group)} ==")
        for p in group:
            print(p.relative_to(root).as_posix())

    print(f"\nBASENAME_DUP_GROUPS {len(basename_groups)}")
    for name, group in sorted(basename_groups.items()):
        print(f"\n== same name {name} x{len(group)} ==")
        for p in group:
            print(p.relative_to(root).as_posix())

    print(f"\nSIMILAR_BASENAME_PAIRS >= {args.min_jaccard:.2f}: {len(similar_pairs)}")
    for sp in similar_pairs[:80]:
        print(f"{sp.score:.3f}\t{sp.a.relative_to(root).as_posix()}\t{sp.b.relative_to(root).as_posix()}")

    # Print clone blocks summary (hash + locations)
    print(f"\nCLONE_BLOCKS (window={block_n} non-empty lines) {len(clone_blocks)}")
    printed = 0
    for h, locs in clone_blocks:
        # Only show blocks that occur in >=2 distinct files
        files = sorted({p for p, _ in locs}, key=lambda p: p.as_posix())
        if len(files) < 2:
            continue
        print(f"\n== clone block {h[:12]} files={len(files)} hits={len(locs)} ==")
        for p, start in sorted(locs, key=lambda t: (t[0].as_posix(), t[1]))[: args.max_block_hits]:
            # line numbers are 1-based
            print(f"{p.relative_to(root).as_posix()}#L{start+1}")
        printed += 1
        if printed >= 40:
            print("\n... (truncated; re-run with different thresholds for more)")
            break

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
