#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass
from pathlib import Path

ROOTS = {
    "CoreKit": Path("RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit"),
    "UIKit": Path("RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit"),
    "Kit": Path("RuntimePackages/SafariLikeKit/Sources/SafariLikeKit"),
}


def iter_swift(root: Path):
    for path in root.rglob("*.swift"):
        # guard against legacy/orphaned copies if they ever appear under scanned roots
        if "/Dev/" in str(path):
            continue
        yield path


def sha256_bytes(data: bytes) -> str:
    h = hashlib.sha256()
    h.update(data)
    return h.hexdigest()


def file_hash(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


EXT_START_RE = re.compile(
    r"\bextension\s+([A-Za-z_][A-Za-z0-9_<>\.:]*)\s*(?:\:.*)?\{", re.M
)


def extract_extension_blocks(text: str):
    blocks: list[tuple[str, str]] = []
    for m in EXT_START_RE.finditer(text):
        type_name = m.group(1)
        start = m.start()
        brace_start = text.find("{", m.end() - 1)
        if brace_start == -1:
            continue

        depth = 0
        i = brace_start
        while i < len(text):
            c = text[i]
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    end = i + 1
                    blocks.append((type_name, text[start:end]))
                    break
            i += 1

    return blocks


def normalize_block(block: str) -> bytes:
    # Best-effort whitespace/comment normalization.
    # (We avoid trying to parse Swift; only used to detect obvious duplicates.)
    s = re.sub(r"//.*", "", block)
    s = re.sub(r"\s+", " ", s).strip()
    return s.encode("utf-8")


@dataclass(frozen=True)
class FileEntry:
    module: str
    path: Path
    sha: str


@dataclass(frozen=True)
class ExtensionEntry:
    type_name: str
    sha: str
    module: str
    path: Path


def main() -> int:
    files: list[FileEntry] = []
    for module, root in ROOTS.items():
        for path in iter_swift(root):
            files.append(FileEntry(module=module, path=path, sha=file_hash(path)))

    by_hash: dict[str, list[FileEntry]] = {}
    for entry in files:
        by_hash.setdefault(entry.sha, []).append(entry)

    file_dupes = {sha: entries for sha, entries in by_hash.items() if len(entries) > 1}

    print(f"SWIFT_FILES {len(files)}")
    print(f"EXACT_FILE_DUP_GROUPS {len(file_dupes)}")

    for sha, entries in sorted(file_dupes.items(), key=lambda kv: (-len(kv[1]), kv[0]))[:50]:
        print(f"\nDUP_GROUP count={len(entries)} sha={sha[:12]}")
        for e in sorted(entries, key=lambda x: (x.module, str(x.path))):
            print(f"  {e.module} {e.path}")

    ext_entries: list[ExtensionEntry] = []
    for module, root in ROOTS.items():
        for path in iter_swift(root):
            txt = read_text(path)
            for type_name, block in extract_extension_blocks(txt):
                sha = sha256_bytes(normalize_block(block))
                ext_entries.append(
                    ExtensionEntry(type_name=type_name, sha=sha, module=module, path=path)
                )

    ext_by_key: dict[tuple[str, str], list[ExtensionEntry]] = {}
    for e in ext_entries:
        ext_by_key.setdefault((e.type_name, e.sha), []).append(e)

    ext_dupes = {k: v for k, v in ext_by_key.items() if len(v) > 1}

    print(f"\nEXT_BLOCKS {len(ext_entries)}")
    print(f"DUP_EXT_BLOCK_GROUPS {len(ext_dupes)}")

    for (type_name, sha), entries in sorted(ext_dupes.items(), key=lambda kv: (-len(kv[1]), kv[0][0], kv[0][1]))[:80]:
        print(f"\nEXT_DUP type={type_name} count={len(entries)} sha={sha[:12]}")
        for e in sorted(entries, key=lambda x: (x.module, str(x.path))):
            print(f"  {e.module} {e.path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
