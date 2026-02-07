from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
KIT = ROOT / "RuntimePackages" / "SafariLikeKit" / "Sources" / "SafariLikeKit"

IMPORT_LINE = re.compile(r"^\s*(?:@_implementationOnly\s+)?import\s+([A-Za-z0-9_\.]+)\s*$")


def has_corekit_import(lines: list[str]) -> bool:
    for line in lines:
        match = IMPORT_LINE.match(line)
        if match and match.group(1) == "SafariLikeCoreKit":
            return True
    return False


def main() -> None:
    if not KIT.exists():
        raise SystemExit(f"SafariLikeKit sources not found: {KIT}")

    changed = 0
    scanned = 0

    for path in KIT.rglob("*.swift"):
        scanned += 1
        text = path.read_text(encoding="utf-8")
        lines = text.splitlines(True)

        if not any(l.strip() for l in lines):
            continue

        if has_corekit_import([l.rstrip("\n") for l in lines]):
            continue

        # Skip leading blank/comment lines.
        i = 0
        while i < len(lines) and (lines[i].strip() == "" or lines[i].lstrip().startswith("//")):
            i += 1

        # Consume contiguous top import block.
        j = i
        while j < len(lines) and IMPORT_LINE.match(lines[j].rstrip("\n")):
            j += 1

        insert_at = j if j > i else 0
        lines.insert(insert_at, "import SafariLikeCoreKit\n")
        path.write_text("".join(lines), encoding="utf-8")
        changed += 1

    print(f"scanned={scanned} changed={changed}")


if __name__ == "__main__":
    main()
