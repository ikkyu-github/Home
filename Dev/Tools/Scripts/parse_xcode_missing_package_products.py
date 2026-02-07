#!/usr/bin/env python3
import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Set, Tuple


MISSING_RE = re.compile(
    r"Missing package product ['\"](?P<product>[^'\"]+)['\"]"  # product name
    r"(?:\s*\(in target ['\"](?P<target>[^'\"]+)['\"] from project ['\"](?P<project>[^'\"]+)['\"]\))?"  # optional target/project
)

CD_RE = re.compile(r"^\s*cd\s+(?P<path>/.+?)\s*$")

# Evidence that SwiftPM packages were resolved/built by Xcode during this build.
PKG_EVIDENCE_RE = re.compile(
    r"SourcePackages/(checkouts|repositories)/|\bResolved source packages\b|\bResolve Package Graph\b|PackageFrameworks/",
    re.IGNORECASE,
)


def read_text_best_effort(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except Exception as e:
        raise RuntimeError(f"Failed to read {path}: {e}")


@dataclass(frozen=True)
class MissingProduct:
    product: str
    target: Optional[str]
    project: Optional[str]
    line: int


@dataclass(frozen=True)
class LogSummary:
    path: Path
    missing: List[MissingProduct]
    cd_paths: List[str]
    has_pkg_evidence: bool


def parse_log(path: Path) -> LogSummary:
    text = read_text_best_effort(path)
    missing: List[MissingProduct] = []
    cd_paths: List[str] = []

    has_pkg_evidence = False

    for idx, line in enumerate(text.splitlines(), start=1):
        if PKG_EVIDENCE_RE.search(line):
            has_pkg_evidence = True

        m_cd = CD_RE.match(line)
        if m_cd:
            cd_paths.append(m_cd.group("path"))

        m = MISSING_RE.search(line)
        if m:
            missing.append(
                MissingProduct(
                    product=m.group("product"),
                    target=m.group("target"),
                    project=m.group("project"),
                    line=idx,
                )
            )

    return LogSummary(path=path, missing=missing, cd_paths=cd_paths, has_pkg_evidence=has_pkg_evidence)


def classify(summary: LogSummary, repo_root: Optional[Path]) -> str:
    """Classify only from evidence present in the log file."""
    if not summary.missing:
        return "(no missing package product errors found)"

    # If we can see Xcode building/resolving SourcePackages/PackageFrameworks in this log,
    # we know SwiftPM integration happened during this build.
    # If not, it's strongly consistent with a resolve failure or a build that never reached package resolution.
    if not summary.has_pkg_evidence:
        return "A? (no SourcePackages/PackageFrameworks/resolve evidence in log; consistent with package resolve not happening or failing early)"

    if repo_root is not None:
        repo_s = str(repo_root)
        # Prefer the last 'cd ...' as the effective working directory.
        if summary.cd_paths:
            last_cd = summary.cd_paths[-1]
            if repo_s not in last_cd:
                return f"C? (log shows build working dir '{last_cd}', which does not match repo root '{repo_s}')"

    # With only missing-product lines and package evidence present, the remaining categories require
    # comparing to project.pbxproj or additional logs.
    return "A/C? (packages appear involved, but log alone is insufficient to distinguish resolve vs wrong project; compare with project.pbxproj + scheme/project path in log)"


def main() -> int:
    ap = argparse.ArgumentParser(description="Parse Xcode build logs for 'Missing package product' errors (workspace-only).")
    ap.add_argument("logs", nargs="+", help="One or more .log files")
    ap.add_argument("--repo-root", default=None, help="Optional repo root path for mismatch checks")
    args = ap.parse_args()

    repo_root = Path(args.repo_root).resolve() if args.repo_root else None

    any_missing = False
    for log in args.logs:
        path = Path(log)
        if not path.exists():
            print(f"ERROR: missing log file: {path}", file=sys.stderr)
            return 2

        summary = parse_log(path)
        print(f"== {path} ==")
        print(f"has_pkg_evidence: {summary.has_pkg_evidence}")
        if summary.cd_paths:
            print(f"cd(last): {summary.cd_paths[-1]}")

        if not summary.missing:
            print("missing_products: (none)")
            print("class: (none)")
            print()
            continue

        any_missing = True
        print("missing_products:")
        for mp in summary.missing:
            t = mp.target if mp.target else "<unknown target>"
            p = mp.project if mp.project else "<unknown project>"
            print(f"- line {mp.line}: product={mp.product} target={t} project={p}")

        print(f"class: {classify(summary, repo_root)}")
        print()

    return 1 if any_missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
