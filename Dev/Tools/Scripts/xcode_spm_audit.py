#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Set, Tuple


TARGETS_OF_INTEREST = {
    "BrowserCore",
    "SafariLikeKit",
    "SafariLikeCoreKit",
    "webOS",
}

IMPORT_MODULES = [
    "Collections",
    "Logging",
]


def _plutil_to_json(path: Path) -> Dict[str, Any]:
    try:
        raw = subprocess.check_output([
            "plutil",
            "-convert",
            "json",
            "-o",
            "-",
            str(path),
        ])
    except FileNotFoundError:
        raise RuntimeError("plutil not found (required on macOS to parse .pbxproj)")
    return json.loads(raw)


@dataclass(frozen=True)
class ProductDep:
    id: str
    product_name: str
    package_id: Optional[str]


@dataclass(frozen=True)
class PackageRef:
    id: str
    url: str


def load_project_objects(pbxproj_path: Path) -> Dict[str, Dict[str, Any]]:
    data = _plutil_to_json(pbxproj_path)
    if "objects" not in data or not isinstance(data["objects"], dict):
        raise RuntimeError("Unexpected .pbxproj JSON structure: missing 'objects'")
    # mypy-ish: ensure dict values are dicts
    objects: Dict[str, Dict[str, Any]] = {}
    for k, v in data["objects"].items():
        if isinstance(v, dict):
            objects[str(k)] = v
    return objects


def collect_packages(objects: Dict[str, Dict[str, Any]]) -> Dict[str, PackageRef]:
    out: Dict[str, PackageRef] = {}
    for oid, obj in objects.items():
        if obj.get("isa") == "XCRemoteSwiftPackageReference":
            url = obj.get("repositoryURL")
            if isinstance(url, str):
                out[oid] = PackageRef(id=oid, url=url)
    return out


def collect_product_deps(objects: Dict[str, Dict[str, Any]]) -> Dict[str, ProductDep]:
    out: Dict[str, ProductDep] = {}
    for oid, obj in objects.items():
        if obj.get("isa") == "XCSwiftPackageProductDependency":
            product_name = obj.get("productName")
            if not isinstance(product_name, str):
                continue
            pkg = obj.get("package")
            out[oid] = ProductDep(id=oid, product_name=product_name, package_id=pkg if isinstance(pkg, str) else None)
    return out


def collect_targets(objects: Dict[str, Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
    out: Dict[str, Dict[str, Any]] = {}
    for oid, obj in objects.items():
        if obj.get("isa") == "PBXNativeTarget" and isinstance(obj.get("name"), str):
            out[obj["name"]] = {"id": oid, **obj}
    return out


def collect_file_refs(objects: Dict[str, Dict[str, Any]]) -> Dict[str, str]:
    out: Dict[str, str] = {}
    for oid, obj in objects.items():
        if obj.get("isa") == "PBXFileReference":
            path = obj.get("path")
            if isinstance(path, str):
                out[oid] = path
    return out


def collect_build_files(objects: Dict[str, Dict[str, Any]]) -> Tuple[Dict[str, str], Dict[str, str]]:
    """Return:
    - build_file_id -> fileRef_id (for sources/resources)
    - build_file_id -> productRef_id (for SwiftPM products)
    """
    to_file_ref: Dict[str, str] = {}
    to_product_ref: Dict[str, str] = {}
    for oid, obj in objects.items():
        if obj.get("isa") != "PBXBuildFile":
            continue
        file_ref = obj.get("fileRef")
        if isinstance(file_ref, str):
            to_file_ref[oid] = file_ref
        product_ref = obj.get("productRef")
        if isinstance(product_ref, str):
            to_product_ref[oid] = product_ref
    return to_file_ref, to_product_ref


def sources_for_target(objects: Dict[str, Dict[str, Any]], target_obj: Dict[str, Any]) -> List[str]:
    """Return a list of PBXBuildFile IDs compiled by the target."""
    build_phase_ids = target_obj.get("buildPhases")
    if not isinstance(build_phase_ids, list):
        return []

    build_file_ids: List[str] = []
    for phase_id in build_phase_ids:
        if not isinstance(phase_id, str):
            continue
        phase = objects.get(phase_id)
        if not isinstance(phase, dict):
            continue
        if phase.get("isa") != "PBXSourcesBuildPhase":
            continue
        files = phase.get("files")
        if isinstance(files, list):
            for bf in files:
                if isinstance(bf, str):
                    build_file_ids.append(bf)
    return build_file_ids


def package_products_for_target(target_obj: Dict[str, Any]) -> List[str]:
    ids = target_obj.get("packageProductDependencies")
    if not isinstance(ids, list):
        return []
    return [x for x in ids if isinstance(x, str)]


def find_imports(repo_root: Path, modules: Iterable[str]) -> Dict[str, List[Path]]:
    out: Dict[str, List[Path]] = {m: [] for m in modules}
    module_set = set(modules)
    import_re = re.compile(r"^\s*import\s+(?P<mod>[A-Za-z0-9_]+)\b", re.MULTILINE)

    for swift_path in repo_root.rglob("*.swift"):
        # Avoid scanning Xcode's derived data if present in-tree (shouldn't be)
        if any(part in {".build", "DerivedData"} for part in swift_path.parts):
            continue
        try:
            text = swift_path.read_text(encoding="utf-8")
        except Exception:
            continue
        mods_in_file: Set[str] = set()
        for m in import_re.finditer(text):
            mod = m.group("mod")
            if mod in module_set:
                mods_in_file.add(mod)
        for mod in sorted(mods_in_file):
            out[mod].append(swift_path)

    for mod in out:
        out[mod].sort()
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="Audit Xcode SwiftPM package products + import->target mapping from project.pbxproj")
    ap.add_argument("--repo-root", default=".", help="Repo root (default: .)")
    ap.add_argument("--pbxproj", default="webOS.xcodeproj/project.pbxproj", help="Path to project.pbxproj")
    ap.add_argument("--targets", nargs="*", default=sorted(TARGETS_OF_INTEREST), help="Targets to report")
    args = ap.parse_args()

    repo_root = Path(args.repo_root).resolve()
    pbxproj_path = (repo_root / args.pbxproj).resolve()
    if not pbxproj_path.exists():
        print(f"ERROR: pbxproj not found: {pbxproj_path}", file=sys.stderr)
        return 2

    objects = load_project_objects(pbxproj_path)
    packages = collect_packages(objects)
    products = collect_product_deps(objects)
    targets = collect_targets(objects)
    file_refs = collect_file_refs(objects)
    buildfile_to_filerefid, buildfile_to_productrefid = collect_build_files(objects)

    # ---- SwiftPM summary ----
    print("== SwiftPM Packages (XCRemoteSwiftPackageReference) ==")
    if not packages:
        print("(none)")
    else:
        for pkg in sorted(packages.values(), key=lambda p: p.url):
            print(f"- {pkg.url} ({pkg.id})")

    print("\n== SwiftPM Products (XCSwiftPackageProductDependency) ==")
    if not products:
        print("(none)")
    else:
        for prod in sorted(products.values(), key=lambda p: p.product_name):
            pkg_url = packages.get(prod.package_id).url if prod.package_id and prod.package_id in packages else "<missing package ref>"
            print(f"- {prod.product_name}: {pkg_url} ({prod.id})")

    # ---- Target product deps ----
    print("\n== Target -> Package Products ==")
    for tname in args.targets:
        tobj = targets.get(tname)
        if not tobj:
            print(f"- {tname}: <target not found in pbxproj>")
            continue
        prod_ids = package_products_for_target(tobj)
        prod_names: List[str] = []
        missing_prod_ids: List[str] = []
        for pid in prod_ids:
            prod = products.get(pid)
            if not prod:
                missing_prod_ids.append(pid)
                continue
            prod_names.append(prod.product_name)
        prod_names_sorted = ", ".join(sorted(set(prod_names))) if prod_names else "(none)"
        print(f"- {tname}: {prod_names_sorted}")
        if missing_prod_ids:
            print(f"  ! Dangling packageProductDependencies IDs: {', '.join(missing_prod_ids)}")

    # ---- Dangling productRef in PBXBuildFile ----
    dangling_product_refs = sorted({
        pref for pref in buildfile_to_productrefid.values() if pref not in products
    })
    print("\n== Integrity Checks ==")
    if dangling_product_refs:
        print("! Dangling PBXBuildFile.productRef -> missing XCSwiftPackageProductDependency:")
        for pref in dangling_product_refs:
            print(f"- {pref}")
    else:
        print("- OK: No dangling PBXBuildFile.productRef")

    # ---- Import -> Target mapping (based on target sources build phase) ----
    imports = find_imports(repo_root, IMPORT_MODULES)
    print("\n== Import -> Target Mapping (from sources build phases) ==")

    # Build: target -> set(relative file paths)
    target_sources: Dict[str, Set[Path]] = {}
    for tname, tobj in targets.items():
        bfile_ids = sources_for_target(objects, tobj)
        paths: Set[Path] = set()
        for bf_id in bfile_ids:
            file_ref_id = buildfile_to_filerefid.get(bf_id)
            if not file_ref_id:
                continue
            rel = file_refs.get(file_ref_id)
            if not rel:
                continue
            paths.add(Path(rel))
        if paths:
            target_sources[tname] = paths

    for mod in IMPORT_MODULES:
        files = imports.get(mod, [])
        if not files:
            print(f"- import {mod}: (no matches in repo .swift files)")
            continue
        print(f"- import {mod}:")
        for f in files:
            rel = f.relative_to(repo_root)
            owning_targets = sorted([
                tname for tname, srcs in target_sources.items() if rel in srcs
            ])
            if not owning_targets:
                owning_targets_s = "<not found in any PBXSourcesBuildPhase>"
            else:
                owning_targets_s = ", ".join(owning_targets)
            print(f"  - {rel} -> {owning_targets_s} -> product '{mod}'")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
