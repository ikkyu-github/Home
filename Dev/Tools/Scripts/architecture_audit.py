#!/usr/bin/env python3

import argparse
import os
import re
import subprocess
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


IMPORT_RE = re.compile(r"^\s*import\s+([A-Za-z_][A-Za-z0-9_]*)\b")
DECL_RE = re.compile(r"^\s*(public\s+)?(final\s+)?(actor|class|struct|enum|protocol)\s+([A-Za-z_][A-Za-z0-9_]*)\b")
REPLACES_RE = re.compile(r"\bReplaces\s*:\s*(.+?)\s*$")

APPLE_MODULE_PREFIXES = {
    # Rough allowlist; anything not in local modules is treated as external.
    "SwiftUI",
    "UIKit",
    "Foundation",
    "Combine",
    "WebKit",
    "OSLog",
    "os",
    "Darwin",
    "CoreGraphics",
    "AVFoundation",
    "UniformTypeIdentifiers",
    "QuickLook",
    "QuartzCore",
    "Security",
    "Network",
}


@dataclass(frozen=True)
class ModuleRoot:
    name: str
    root: Path


def repo_root_from_script() -> Path:
    """Find workspace root by walking upward for known markers."""
    script_path = Path(__file__).resolve()
    for p in [Path.cwd(), script_path] + list(script_path.parents):
        if (p / "RuntimePackages").exists() and (p / "App").exists():
            return p
        if (p / "RuntimePackages").exists() and (p / "webOS.xcodeproj").exists():
            return p
    # Fallback to current directory.
    return Path.cwd().resolve()


def discover_local_modules(root: Path) -> list[ModuleRoot]:
    modules: list[ModuleRoot] = []

    # App target (Xcode): treat as a module for import/layer rules.
    app_dir = root / "App"
    if app_dir.exists():
        modules.append(ModuleRoot("App", app_dir))

    runtime = root / "RuntimePackages"
    if runtime.exists():
        for pkg in runtime.iterdir():
            sources = pkg / "Sources"
            if not sources.exists():
                continue
            for target in sources.iterdir():
                if target.is_dir():
                    modules.append(ModuleRoot(target.name, target))

    # Deduplicate by name (prefer the first found).
    seen = set()
    unique: list[ModuleRoot] = []
    for m in modules:
        if m.name in seen:
            continue
        seen.add(m.name)
        unique.append(m)
    return unique


def iter_swift_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for p in root.rglob("*.swift"):
        if "/.build/" in str(p):
            continue
        if "/build/" in str(p):
            continue
        files.append(p)
    return files


def owner_module_for(path: Path, modules: list[ModuleRoot]) -> Optional[str]:
    s = str(path)
    best = None
    best_len = -1
    for m in modules:
        prefix = str(m.root)
        if s.startswith(prefix) and len(prefix) > best_len:
            best = m.name
            best_len = len(prefix)
    return best


def parse_imports(path: Path) -> set[str]:
    imports: set[str] = set()
    try:
        with path.open("r", encoding="utf-8") as f:
            for line in f:
                m = IMPORT_RE.match(line)
                if m:
                    imports.add(m.group(1))
    except Exception:
        return imports
    return imports


def parse_decls(path: Path) -> set[str]:
    decls: set[str] = set()
    try:
        with path.open("r", encoding="utf-8") as f:
            for line in f:
                m = DECL_RE.match(line)
                if m:
                    decls.add(m.group(4))
    except Exception:
        return decls
    return decls


def build_import_graph(modules: list[ModuleRoot]) -> tuple[dict[str, set[str]], dict[str, list[tuple[Path, str]]]]:
    module_names = {m.name for m in modules}

    edges: dict[str, set[str]] = {m.name: set() for m in modules}
    evidence: dict[str, list[tuple[Path, str]]] = defaultdict(list)

    for m in modules:
        for swift in iter_swift_files(m.root):
            for imp in parse_imports(swift):
                if imp in module_names and imp != m.name:
                    edges[m.name].add(imp)
                    evidence[f"{m.name}->{imp}"].append((swift, imp))

    return edges, evidence


def find_cycles(edges: dict[str, set[str]]) -> list[list[str]]:
    # Standard DFS cycle detection.
    cycles: list[list[str]] = []
    temp: set[str] = set()
    perm: set[str] = set()
    stack: list[str] = []

    def visit(n: str):
        if n in perm:
            return
        if n in temp:
            # Extract cycle from stack.
            if n in stack:
                idx = stack.index(n)
                cycle = stack[idx:] + [n]
                cycles.append(cycle)
            return

        temp.add(n)
        stack.append(n)
        for nxt in sorted(edges.get(n, [])):
            visit(nxt)
        stack.pop()
        temp.remove(n)
        perm.add(n)

    for node in sorted(edges.keys()):
        visit(node)

    # Deduplicate cycles by canonical rotation.
    def canon(c: list[str]) -> tuple[str, ...]:
        if len(c) < 2:
            return tuple(c)
        # remove last repeated
        core = c[:-1]
        rots = [tuple(core[i:] + core[:i]) for i in range(len(core))]
        best = min(rots)
        return best

    seen = set()
    uniq: list[list[str]] = []
    for c in cycles:
        k = canon(c)
        if k in seen:
            continue
        seen.add(k)
        uniq.append(c)

    return uniq


def duplicate_basenames(modules: list[ModuleRoot]) -> dict[str, list[Path]]:
    by_base: dict[str, list[Path]] = defaultdict(list)
    for m in modules:
        for swift in iter_swift_files(m.root):
            by_base[swift.name].append(swift)
    return {k: v for k, v in by_base.items() if len(v) > 1}


def duplicate_type_names(modules: list[ModuleRoot]) -> dict[str, list[tuple[str, Path]]]:
    by_name: dict[str, list[tuple[str, Path]]] = defaultdict(list)
    for m in modules:
        for swift in iter_swift_files(m.root):
            for t in parse_decls(swift):
                by_name[t].append((m.name, swift))

    # Keep only duplicates across different modules.
    dup: dict[str, list[tuple[str, Path]]] = {}
    for name, locs in by_name.items():
        mods = {mod for mod, _ in locs}
        if len(mods) > 1:
            dup[name] = locs
    return dup


def check_layer_rules(root: Path, edges: dict[str, set[str]]) -> list[str]:
    problems: list[str] = []

    def forbid(src: str, dst: str, reason: str):
        if dst in edges.get(src, set()):
            problems.append(f"FORBIDDEN: {src} imports {dst} ({reason})")

    # Architecture contract (tune as needed)
    # App is composition root: it may only depend on SafariLikeKit (local), plus Apple/system modules.
    forbid("App", "SafariLikeCoreKit", "App must be facade-only")
    forbid("App", "SafariLikeUIKit", "App must be facade-only")
    forbid("App", "SafariLikeUXKit", "App must be facade-only")
    forbid("App", "BrowserCore", "App must be facade-only")
    forbid("App", "SafariLikeContracts", "App must be facade-only")

    # Facade must not depend on the UIKit host package.
    forbid("SafariLikeKit", "SafariLikeUIKit", "Facade must not import host layer")

    # UIKit host should not reach into engine/core internals (use facade + contracts).
    forbid("SafariLikeUIKit", "BrowserCore", "Host must not import core internals")
    forbid("SafariLikeUIKit", "SafariLikeCoreKit", "Host must not import engine internals")

    # Low layers must not depend on higher layers.
    forbid("SafariLikeContracts", "BrowserCore", "Contracts must be bottom layer")
    forbid("SafariLikeContracts", "SafariLikeCoreKit", "Contracts must be bottom layer")
    forbid("SafariLikeContracts", "SafariLikeKit", "Contracts must be bottom layer")
    forbid("SafariLikeContracts", "SafariLikeUIKit", "Contracts must be bottom layer")
    forbid("SafariLikeContracts", "SafariLikeUXKit", "Contracts must be bottom layer")

    forbid("BrowserCore", "SafariLikeCoreKit", "Core must not depend on engine")
    forbid("BrowserCore", "SafariLikeKit", "Core must not depend on facade")
    forbid("BrowserCore", "SafariLikeUIKit", "Core must not depend on host")
    forbid("BrowserCore", "SafariLikeUXKit", "Core must not depend on UX")

    forbid("SafariLikeCoreKit", "SafariLikeKit", "Engine must not depend on facade")
    forbid("SafariLikeCoreKit", "SafariLikeUIKit", "Engine must remain UIKit-free")
    forbid("SafariLikeCoreKit", "SafariLikeUXKit", "Engine must not depend on UX")

    # UX is policy/layout: ideally should not depend on SafariLikeKit or engine.
    forbid("SafariLikeUXKit", "SafariLikeKit", "UX must not depend on facade")
    forbid("SafariLikeUXKit", "SafariLikeCoreKit", "UX must not depend on engine")
    forbid("SafariLikeUXKit", "SafariLikeUIKit", "UX must not depend on host")

    return problems


def check_forbidden_imports_in_paths(root: Path, modules: list[ModuleRoot]) -> list[str]:
    problems: list[str] = []

    module_by_name = {m.name: m for m in modules}

    def check_dir(owner: str, rel_dir: str, forbidden: set[str], reason: str):
        mod = module_by_name.get(owner)
        if not mod:
            return
        base = mod.root / rel_dir
        if not base.exists():
            return
        for swift in iter_swift_files(base):
            for imp in sorted(parse_imports(swift)):
                if imp in forbidden:
                    rel = swift.relative_to(root)
                    problems.append(f"FORBIDDEN IMPORT: {rel} imports {imp} ({reason})")

    # Plugins must depend on Contracts only (plus Apple/system frameworks).
    check_dir(
        owner="SafariLikeKit",
        rel_dir="Plugins/Examples",
        forbidden={"BrowserCore", "SafariLikeCoreKit", "SafariLikeKit", "SafariLikeUIKit", "SafariLikeUXKit"},
        reason="Plugin implementations must be Contracts-only",
    )

    # UI host must not import core/engine.
    check_dir(
        owner="SafariLikeUIKit",
        rel_dir=".",
        forbidden={"BrowserCore", "SafariLikeCoreKit"},
        reason="UIKit host must use facade + contracts only",
    )

    return problems


def write_dot(root: Path, edges: dict[str, set[str]], out_path: Path):
    lines = ["digraph Modules {", "  rankdir=LR;"]
    for src, dsts in sorted(edges.items()):
        if not dsts:
            lines.append(f"  \"{src}\";")
        for dst in sorted(dsts):
            lines.append(f"  \"{src}\" -> \"{dst}\";")
    lines.append("}")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def run_git(root: Path, args: list[str]) -> str:
    proc = subprocess.run(
        ["git", *args],
        cwd=str(root),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "git command failed")
    return proc.stdout


def is_git_repo(root: Path) -> bool:
    try:
        out = run_git(root, ["rev-parse", "--is-inside-work-tree"])
        return out.strip() == "true"
    except Exception:
        return False


def git_ref_exists(root: Path, ref: str) -> bool:
    try:
        proc = subprocess.run(
            ["git", "rev-parse", "--verify", "--quiet", ref],
            cwd=str(root),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        return proc.returncode == 0
    except Exception:
        return False


def default_git_base(root: Path) -> str:
    for ref in ("origin/main", "main", "origin/master", "master"):
        if git_ref_exists(root, ref):
            return ref
    return "HEAD~1"


@dataclass(frozen=True)
class GitChangeSet:
    base: str
    head: str
    added_files: set[str]
    deleted_files: set[str]
    renamed_from: set[str]
    renamed_to: set[str]
    net_loc: int
    numstat_by_path: dict[str, tuple[int, int]]


IGNORED_PATH_PREFIXES = (
    "build/",
    "DerivedData/",
    ".build/",
    ".swiftpm/",
    ".git/",
)


def is_ignored_path(rel: str) -> bool:
    rel = rel.replace("\\", "/")
    return any(rel.startswith(p) for p in IGNORED_PATH_PREFIXES)


def count_file_lines(path: Path) -> int:
    try:
        # Count lines without loading huge files into memory.
        n = 0
        with path.open("rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                n += chunk.count(b"\n")
        return n
    except Exception:
        return 0


def parse_git_changes(
    root: Path,
    base: str,
    head: str = "HEAD",
    *,
    include_untracked: bool = False,
) -> GitChangeSet:
    name_status = run_git(root, ["diff", "--name-status", f"{base}...{head}"])
    added: set[str] = set()
    deleted: set[str] = set()
    renamed_from: set[str] = set()
    renamed_to: set[str] = set()

    for raw in name_status.splitlines():
        if not raw.strip():
            continue
        parts = raw.split("\t")
        status = parts[0]
        if status == "A" and len(parts) >= 2:
            added.add(parts[1])
        elif status == "D" and len(parts) >= 2:
            deleted.add(parts[1])
        elif status.startswith("R") and len(parts) >= 3:
            renamed_from.add(parts[1])
            renamed_to.add(parts[2])

    numstat = run_git(root, ["diff", "--numstat", f"{base}...{head}"])
    numstat_by_path: dict[str, tuple[int, int]] = {}
    net_loc = 0
    for raw in numstat.splitlines():
        if not raw.strip():
            continue
        parts = raw.split("\t")
        if len(parts) < 3:
            continue
        add_s, del_s, path = parts[0], parts[1], parts[2]
        if add_s == "-" or del_s == "-":
            a = 0
            d = 0
        else:
            try:
                a = int(add_s)
                d = int(del_s)
            except ValueError:
                continue
        numstat_by_path[path] = (a, d)
        net_loc += a - d

    if include_untracked:
        # Include untracked files when requested (local dev convenience).
        # CI/PR diffs are tracked-only, so this is opt-in to avoid noise.
        try:
            status = run_git(root, ["status", "--porcelain"])
            for raw in status.splitlines():
                if raw.startswith("?? "):
                    rel = raw[3:].strip()
                    if not rel or is_ignored_path(rel):
                        continue
                    added.add(rel)
        except Exception:
            pass

    return GitChangeSet(
        base=base,
        head=head,
        added_files=added,
        deleted_files=deleted,
        renamed_from=renamed_from,
        renamed_to=renamed_to,
        net_loc=net_loc,
        numstat_by_path=numstat_by_path,
    )


def read_replaces_marker(root: Path, rel_path: str, *, max_lines: int = 60) -> Optional[str]:
    p = root / rel_path
    try:
        with p.open("r", encoding="utf-8") as f:
            for _ in range(max_lines):
                line = f.readline()
                if not line:
                    break
                m = REPLACES_RE.search(line)
                if m:
                    return m.group(1).strip()
    except Exception:
        return None
    return None


def is_safe_rel_path(p: str) -> bool:
    if not p or p.startswith("/"):
        return False
    parts = Path(p).parts
    if any(seg in ("..",) for seg in parts):
        return False
    return True


def file_declares_suffix(root: Path, rel_path: str, *, suffix: str) -> bool:
    p = root / rel_path
    try:
        with p.open("r", encoding="utf-8") as f:
            for line in f:
                m = DECL_RE.match(line)
                if not m:
                    continue
                name = m.group(4)
                if name.endswith(suffix):
                    return True
    except Exception:
        return False
    return False


def anti_bloat_check(root: Path, changes: GitChangeSet) -> list[str]:
    problems: list[str] = []

    # Rule 1: every refactor must either delete a file or reduce total LOC.
    # Enforced as: pass if (any file deleted/renamed-away) OR (net LOC <= 0).
    deleted_or_renamed = len(changes.deleted_files) + len(changes.renamed_from)
    if deleted_or_renamed == 0 and changes.net_loc > 0:
        problems.append(
            f"ANTI-BLOAT: net LOC increased by {changes.net_loc} and no files were deleted (base={changes.base})."
        )

    # Rule 2: adding a file requires naming the file it replaces.
    # We enforce this for code-ish files only.
    enforce_exts = {".swift", ".py", ".sh"}
    for rel in sorted(changes.added_files):
        if is_ignored_path(rel):
            continue
        ext = Path(rel).suffix
        if ext not in enforce_exts:
            continue
        replaces = read_replaces_marker(root, rel)
        if not replaces:
            problems.append(
                f"ANTI-BLOAT: {rel} is a new file; add a 'Replaces: <path>' marker near the top."
            )
            continue
        if not is_safe_rel_path(replaces):
            problems.append(
                f"ANTI-BLOAT: {rel} has invalid Replaces path: '{replaces}' (must be repo-relative, no '..')."
            )
            continue

        # Replacement must be observable in the diff: deleted/renamed-away or net-deleted.
        if replaces in changes.deleted_files or replaces in changes.renamed_from:
            pass
        else:
            # numstat uses paths as reported by git; we only accept a strict match.
            stats = changes.numstat_by_path.get(replaces)
            if not stats:
                problems.append(
                    f"ANTI-BLOAT: {rel} claims to replace {replaces}, but {replaces} is not deleted or modified in this diff."
                )
            else:
                a, d = stats
                if (a - d) >= 0:
                    problems.append(
                        f"ANTI-BLOAT: {rel} claims to replace {replaces}, but {replaces} did not shrink (added={a}, deleted={d})."
                    )

        # Rule 3: no new ViewModel unless replacing an existing one.
        if ext == ".swift" and file_declares_suffix(root, rel, suffix="ViewModel"):
            # Already enforced via Replaces marker + replacement validation above.
            pass

        # Rule 4: no new Store unless replacing derived state.
        if ext == ".swift" and file_declares_suffix(root, rel, suffix="Store"):
            # Already enforced via Replaces marker + replacement validation above.
            pass

    # Rule 3/4 (stronger): no new ViewModel/Store type declarations unless an existing one is removed.
    # This catches additions inside existing files (not only new files).
    try:
        diff_text = run_git(root, ["diff", "-U0", f"{changes.base}...{changes.head}"])
        added_viewmodels: set[str] = set()
        removed_viewmodels: set[str] = set()
        added_stores: set[str] = set()
        removed_stores: set[str] = set()

        for raw in diff_text.splitlines():
            if not raw:
                continue
            if raw.startswith("+++") or raw.startswith("---"):
                continue
            if raw.startswith("+"):
                line = raw[1:]
                m = DECL_RE.match(line)
                if m:
                    name = m.group(4)
                    if name.endswith("ViewModel"):
                        added_viewmodels.add(name)
                    if name.endswith("Store"):
                        added_stores.add(name)
            elif raw.startswith("-"):
                line = raw[1:]
                m = DECL_RE.match(line)
                if m:
                    name = m.group(4)
                    if name.endswith("ViewModel"):
                        removed_viewmodels.add(name)
                    if name.endswith("Store"):
                        removed_stores.add(name)

        new_viewmodels = sorted(added_viewmodels - removed_viewmodels)
        new_stores = sorted(added_stores - removed_stores)

        if new_viewmodels:
            problems.append(
                "ANTI-BLOAT: new ViewModel type(s) added without removing an existing one: "
                + ", ".join(new_viewmodels)
            )
        if new_stores:
            problems.append(
                "ANTI-BLOAT: new Store type(s) added without removing an existing one: "
                + ", ".join(new_stores)
            )
    except Exception:
        # If diff parsing fails, don't block the audit; other checks still apply.
        pass

    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description="Architecture audit: dependency graph, cycles, duplicates, layer rules")
    parser.add_argument("--dot", action="store_true", help="Write build/architecture/module_graph.dot")
    parser.add_argument("--fail-on-warn", action="store_true", help="Exit non-zero on duplicate basenames/type names")
    parser.add_argument(
        "--anti-bloat",
        action="store_true",
        help="Enforce anti-bloat rules via git diff (net LOC + replacement markers)",
    )
    parser.add_argument(
        "--base",
        default=None,
        help="Git base ref to compare against (default: origin/main if available, else HEAD~1)",
    )
    parser.add_argument(
        "--metrics",
        action="store_true",
        help="Print current repo size metrics (tracked Swift file count + LOC)",
    )
    parser.add_argument(
        "--include-untracked",
        action="store_true",
        help="Include untracked files in anti-bloat checks (local-only convenience)",
    )
    args = parser.parse_args()

    root = repo_root_from_script()
    modules = discover_local_modules(root)
    edges, _ = build_import_graph(modules)

    print("== Modules ==")
    for m in sorted({m.name for m in modules}):
        print(f"- {m}")

    print("\n== Module Import Graph (local edges) ==")
    for src in sorted(edges.keys()):
        dsts = sorted(edges[src])
        print(f"- {src}: {', '.join(dsts) if dsts else '(none)'}")

    cycles = find_cycles(edges)
    print("\n== Circular References ==")
    if not cycles:
        print("- none detected (module-level imports)")
    else:
        for c in cycles:
            print("- " + " -> ".join(c))

    problems = check_layer_rules(root, edges)
    problems += check_forbidden_imports_in_paths(root, modules)
    print("\n== Layer Rules ==")
    if not problems:
        print("- OK")
    else:
        for p in problems:
            print(f"- {p}")

    dup_files = duplicate_basenames(modules)
    print("\n== Duplicate Filenames (.swift) ==")
    if not dup_files:
        print("- none")
    else:
        for base, paths in sorted(dup_files.items()):
            print(f"- {base}")
            for p in sorted(paths):
                rel = p.relative_to(root)
                print(f"    - {rel}")

    dup_types = duplicate_type_names(modules)
    print("\n== Duplicate Type Names (heuristic) ==")
    if not dup_types:
        print("- none")
    else:
        # Print a capped list (can be noisy)
        cap = 50
        for i, (name, locs) in enumerate(sorted(dup_types.items())):
            if i >= cap:
                print(f"- ... ({len(dup_types) - cap} more)")
                break
            mods = sorted({m for m, _ in locs})
            print(f"- {name} (modules: {', '.join(mods)})")

    if args.dot:
        out = root / "build" / "architecture" / "module_graph.dot"
        write_dot(root, edges, out)
        print(f"\nWrote: {out.relative_to(root)}")

    if args.metrics:
        print("\n== Size Metrics ==")
        if not is_git_repo(root):
            print("- ERROR: not a git repository; metrics require git")
            return 2

        swift_files = [p for p in run_git(root, ["ls-files", "*.swift"]).splitlines() if p]
        # Note: line counting is best-effort and can be a little slow; keep it simple.
        swift_loc = sum(count_file_lines(root / p) for p in swift_files)
        print(f"- tracked_swift_files: {len(swift_files)}")
        print(f"- tracked_swift_loc: {swift_loc}")

    if args.anti_bloat:
        print("\n== Anti-Bloat Rules ==")
        if not is_git_repo(root):
            print("- ERROR: not a git repository; cannot run anti-bloat checks")
            return 2

        base = args.base or default_git_base(root)
        try:
            changes = parse_git_changes(root, base=base, include_untracked=args.include_untracked)
        except Exception as e:
            print(f"- ERROR: failed to read git diff: {e}")
            return 2

        anti = anti_bloat_check(root, changes)
        if not anti:
            print("- OK")
        else:
            for p in anti:
                print(f"- {p}")

    exit_code = 0
    if problems:
        exit_code = 2
    if args.anti_bloat:
        base = args.base or default_git_base(root)
        try:
            changes = parse_git_changes(root, base=base, include_untracked=args.include_untracked)
            anti = anti_bloat_check(root, changes)
        except Exception:
            anti = ["ANTI-BLOAT: failed to evaluate git diff"]
        if anti:
            exit_code = max(exit_code, 2)
    if args.fail_on_warn and (dup_files or dup_types):
        exit_code = max(exit_code, 3)

    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
