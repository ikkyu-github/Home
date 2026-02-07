#!/usr/bin/env python3

import re
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Candidate:
    path: str
    line: int
    kind: str
    name: str


ROOTS = [
    Path("App"),
    Path("BrowserCore"),
    Path("SafariLikeCoreKit"),
    Path("SafariLikeKit"),
    Path("SafariLikeUIKit"),
]

FUNC_RE = re.compile(
    r"^(?P<attrs>(?:@[^\n]*\n\s*)*)?"
    r"(?P<access>private|fileprivate)\s+"
    r"(?:(?:final|static|class|convenience|mutating|nonmutating)\s+)*"
    r"func\s+"
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*\(",
    re.MULTILINE,
)

TYPE_RE = re.compile(
    r"^(?P<attrs>(?:@[^\n]*\n\s*)*)?"
    r"(?P<access>private|fileprivate)\s+"
    r"(?P<kind>struct|enum|class)\s+"
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)\b",
    re.MULTILINE,
)


def _is_objc_related(attrs: str) -> bool:
    if not attrs:
        return False
    for line in attrs.splitlines():
        s = line.strip()
        if s.startswith("@objc") or s.startswith("@IBAction"):
            return True
    return False


def _has_selector_like_usage(text: str, name: str) -> bool:
    escaped = re.escape(name)
    patterns = [
        rf"#selector\([^\)]*\b{escaped}\b",
        rf"NSSelectorFromString\(\s*\"{escaped}\"\s*\)",
        rf"Selector\(\s*\"{escaped}\"\s*\)",
    ]
    return any(re.search(p, text) for p in patterns)


def _count_word(text: str, word: str) -> int:
    return len(re.findall(rf"\b{re.escape(word)}\b", text))


def _strip_comments(text: str) -> str:
    # Strip comments only (keep string literals) to avoid false positives
    # for identifiers referenced inside string interpolation: "...\(foo())...".
    text = re.sub(r"/\*[\s\S]*?\*/", " ", text)
    text = re.sub(r"//.*", " ", text)
    return text


def scan() -> list[Candidate]:
    out: list[Candidate] = []

    for root in ROOTS:
        if not root.exists():
            continue
        for path in root.rglob("*.swift"):
            try:
                text = path.read_text(encoding="utf-8")
            except Exception:
                # Defensive: ignore unreadable files
                continue

            stripped = _strip_comments(text)

            # private/fileprivate funcs
            for m in FUNC_RE.finditer(text):
                name = m.group("name")
                attrs = m.group("attrs") or ""

                if _is_objc_related(attrs):
                    continue

                # Heuristic: if the identifier only appears once in the file,
                # it is likely unused (and safe to consider for deletion).
                if _count_word(stripped, name) != 1:
                    continue

                if _has_selector_like_usage(text, name):
                    continue

                line = text.count("\n", 0, m.start()) + 1
                out.append(Candidate(str(path), line, "func", name))

            # private/fileprivate types
            for m in TYPE_RE.finditer(text):
                name = m.group("name")
                attrs = m.group("attrs") or ""
                kind = m.group("kind")

                if _is_objc_related(attrs):
                    continue

                if _count_word(stripped, name) != 1:
                    continue

                line = text.count("\n", 0, m.start()) + 1
                out.append(Candidate(str(path), line, kind, name))

    out.sort(key=lambda c: (c.path, c.line, c.kind, c.name))
    return out


if __name__ == "__main__":
    candidates = scan()
    print(f"Found {len(candidates)} conservative candidates")
    for c in candidates[:200]:
        print(f"{c.path}:{c.line}: {c.kind} {c.name}")
    if len(candidates) > 200:
        print(f"... and {len(candidates) - 200} more")
