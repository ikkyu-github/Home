#!/usr/bin/env python3

import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple


ROOT_DIR = Path(__file__).resolve().parents[3]
PBXPROJ_PATH = ROOT_DIR / "webOS.xcodeproj" / "project.pbxproj"
RESOLVED_PATH = ROOT_DIR / "webOS.xcodeproj" / "project.xcworkspace" / "xcshareddata" / "swiftpm" / "Package.resolved"

REQUIRED_TARGETS = [
    "SafariLikeKit",
    "SafariLikeCoreKit",
    "BrowserCore",
    "webOS",
]

REQUIRED_PACKAGES = {
    "swift-log": "https://github.com/apple/swift-log.git",
    "swift-collections": "https://github.com/apple/swift-collections.git",
}

REQUIRED_PRODUCTS = ["Logging", "Collections"]


class CheckFailed(Exception):
    pass


def _run(cmd: List[str], cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=str(cwd), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise CheckFailed(message)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        raise CheckFailed(f"missing file: {path}")


def find_section(text: str, section_name: str) -> str:
    # Sections in pbxproj:
    # /* Begin <name> section */
    # ...
    # /* End <name> section */
    m = re.search(
        rf"/\* Begin {re.escape(section_name)} section \*/(.*?)/\* End {re.escape(section_name)} section \*/",
        text,
        flags=re.S,
    )
    require(bool(m), f"pbxproj missing section: {section_name}")
    return m.group(1)


@dataclass(frozen=True)
class RemotePackageRef:
    object_id: str
    name: str
    repository_url: str


@dataclass(frozen=True)
class ProductDep:
    object_id: str
    product_name: str
    package_ref_id: str


@dataclass(frozen=True)
class TargetInfo:
    object_id: str
    name: str
    package_product_dependency_ids: Tuple[str, ...]


def parse_remote_packages(pbxproj_text: str) -> Dict[str, RemotePackageRef]:
    section = find_section(pbxproj_text, "XCRemoteSwiftPackageReference")
    # Example:
    # 5F... /* XCRemoteSwiftPackageReference "swift-log" */ = {
    #   isa = XCRemoteSwiftPackageReference;
    #   repositoryURL = "https://...";
    #   requirement = {...};
    # };
    pattern = re.compile(
        r"\n\s*(?P<id>[A-F0-9]{24})\s*/\*\s*XCRemoteSwiftPackageReference\s*\"(?P<name>[^\"]+)\"\s*\*/\s*=\s*\{"
        r"(?P<body>.*?)\n\s*\};",
        flags=re.S,
    )
    out: Dict[str, RemotePackageRef] = {}
    for m in pattern.finditer(section):
        oid = m.group("id")
        name = m.group("name")
        body = m.group("body")
        url_match = re.search(r'repositoryURL\s*=\s*"([^"]+)";', body)
        if not url_match:
            continue
        out[name] = RemotePackageRef(object_id=oid, name=name, repository_url=url_match.group(1))
    return out


def parse_product_deps(pbxproj_text: str) -> Dict[str, ProductDep]:
    section = find_section(pbxproj_text, "XCSwiftPackageProductDependency")
    # Example:
    # 5F... /* Logging */ = {
    #   isa = XCSwiftPackageProductDependency;
    #   package = 5F... /* XCRemoteSwiftPackageReference "swift-log" */;
    #   productName = Logging;
    # };
    pattern = re.compile(
        r"\n\s*(?P<id>[A-F0-9]{24})\s*/\*\s*(?P<label>[^*]+?)\s*\*/\s*=\s*\{"
        r"(?P<body>.*?)\n\s*\};",
        flags=re.S,
    )
    out: Dict[str, ProductDep] = {}
    for m in pattern.finditer(section):
        oid = m.group("id")
        body = m.group("body")
        pkg_match = re.search(r"package\s*=\s*([A-F0-9]{24})\s*/\*\s*XCRemoteSwiftPackageReference\s*\"([^\"]+)\"\s*\*/;", body)
        prod_match = re.search(r"productName\s*=\s*([A-Za-z0-9_]+);", body)
        if not (pkg_match and prod_match):
            continue
        product_name = prod_match.group(1)
        package_ref_id = pkg_match.group(1)
        out[product_name] = ProductDep(object_id=oid, product_name=product_name, package_ref_id=package_ref_id)
    return out


def parse_targets(pbxproj_text: str) -> Dict[str, TargetInfo]:
    section = find_section(pbxproj_text, "PBXNativeTarget")

    # Target objects look like:
    # <id> /* Name */ = {
    #   isa = PBXNativeTarget;
    #   ...
    #   name = Name;
    #   packageProductDependencies = (
    #       <id> /* Logging */,
    #       ...
    #   );
    # };
    pattern = re.compile(
        r"\n\s*(?P<id>[A-F0-9]{24})\s*/\*\s*(?P<label>[^*]+?)\s*\*/\s*=\s*\{"
        r"(?P<body>.*?)\n\s*\};",
        flags=re.S,
    )

    out: Dict[str, TargetInfo] = {}
    for m in pattern.finditer(section):
        oid = m.group("id")
        body = m.group("body")

        name_match = re.search(r"\n\s*name\s*=\s*([A-Za-z0-9_]+);", body)
        if not name_match:
            continue
        name = name_match.group(1)

        deps: List[str] = []
        deps_match = re.search(r"packageProductDependencies\s*=\s*\((.*?)\);", body, flags=re.S)
        if deps_match:
            deps_body = deps_match.group(1)
            for dep_id in re.findall(r"\b([A-F0-9]{24})\b\s*/\*", deps_body):
                deps.append(dep_id)

        out[name] = TargetInfo(object_id=oid, name=name, package_product_dependency_ids=tuple(deps))

    return out


def check_package_resolved_is_tracked() -> None:
    git_dir = ROOT_DIR / ".git"
    if not git_dir.exists():
        return

    # Note: some repos choose not to track Xcode's Package.resolved.
    # We only warn here so this script can be used in both workflows.
    cp = _run(["git", "ls-files", "--error-unmatch", str(RESOLVED_PATH.relative_to(ROOT_DIR))], cwd=ROOT_DIR)
    if cp.returncode != 0:
        print(f"WARN: Package.resolved is not tracked by git: {RESOLVED_PATH}")


def main() -> int:
    try:
        pbxproj = read_text(PBXPROJ_PATH)
        resolved = read_text(RESOLVED_PATH)

        # 1) Package.resolved sanity: should mention the packages we rely on.
        for pkg_name in REQUIRED_PACKAGES.keys():
            require(pkg_name in resolved, f"Package.resolved does not mention required package: {pkg_name}")

        check_package_resolved_is_tracked()

        # 2) pbxproj: remote package refs must exist and point to expected repo URLs.
        remote_pkgs = parse_remote_packages(pbxproj)
        for pkg_name, expected_url in REQUIRED_PACKAGES.items():
            require(pkg_name in remote_pkgs, f"pbxproj missing XCRemoteSwiftPackageReference for: {pkg_name}")
            actual_url = remote_pkgs[pkg_name].repository_url
            require(
                actual_url == expected_url,
                f"pbxproj package URL mismatch for {pkg_name}: expected {expected_url} but found {actual_url}",
            )

        # 3) pbxproj: product dependencies must exist and be linked to the correct remote package refs.
        product_deps = parse_product_deps(pbxproj)
        for prod in REQUIRED_PRODUCTS:
            require(prod in product_deps, f"pbxproj missing XCSwiftPackageProductDependency for product: {prod}")

        # Cross-check: product deps reference the correct remote package IDs.
        # Logging -> swift-log, Collections -> swift-collections
        expected_pkg_for_product = {
            "Logging": "swift-log",
            "Collections": "swift-collections",
        }
        for prod, pkg_name in expected_pkg_for_product.items():
            pkg_ref_id_expected = remote_pkgs[pkg_name].object_id
            pkg_ref_id_actual = product_deps[prod].package_ref_id
            require(
                pkg_ref_id_actual == pkg_ref_id_expected,
                f"pbxproj product '{prod}' is linked to wrong package ref id: expected {pkg_ref_id_expected} but found {pkg_ref_id_actual}",
            )

        # 4) Target-level linkage: each required target must list both product dep IDs.
        targets = parse_targets(pbxproj)
        missing_targets: List[str] = []

        logging_id = product_deps["Logging"].object_id
        collections_id = product_deps["Collections"].object_id

        for tname in REQUIRED_TARGETS:
            require(tname in targets, f"pbxproj missing required target: {tname}")
            deps = set(targets[tname].package_product_dependency_ids)
            missing: List[str] = []
            if logging_id not in deps:
                missing.append("Logging")
            if collections_id not in deps:
                missing.append("Collections")
            if missing:
                missing_targets.append(f"{tname}: missing {', '.join(missing)}")

        require(not missing_targets, "Missing target packageProductDependencies:\n" + "\n".join(missing_targets))

        print("OK: SwiftPM linkage + Package.resolved lock look consistent")
        return 0
    except CheckFailed as e:
        print(f"ERROR: {e}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
