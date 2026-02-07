from __future__ import annotations

import shutil
from pathlib import Path


def main() -> int:
    root = Path(".")
    manifest: list[str] = []

    # Move deeper paths first to avoid moving a parent before a child.
    test_dirs = [
        p
        for p in root.rglob("*")
        if p.is_dir() and p.name.endswith("Tests") and (not p.parts or p.parts[0] != "Dev")
    ]
    test_dirs.sort(key=lambda p: len(p.as_posix()), reverse=True)

    for src in test_dirs:
        dest = root / "Dev" / "Tests" / src
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(src), str(dest))
        manifest.append(f"{src.as_posix()} -> {dest.as_posix()}")

    Path("Dev/move_manifest_tests.txt").write_text(
        "\n".join(manifest) + ("\n" if manifest else "")
    )
    print(f"Moved {len(manifest)} test directories")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
