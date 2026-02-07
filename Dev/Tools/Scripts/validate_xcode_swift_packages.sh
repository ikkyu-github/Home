#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

PROJECT_PATH="${WEBOS_XCODE_PROJECT_PATH:-$ROOT_DIR/webOS.xcodeproj/project.pbxproj}"

if [[ ! -f "$PROJECT_PATH" ]]; then
  echo "[xcode-pkg-validate][ERROR] Missing pbxproj: $PROJECT_PATH" >&2
  exit 2
fi

python3 - "$PROJECT_PATH" <<'PY'
import re
import sys
from pathlib import Path

pbxproj_path = Path(sys.argv[1])
text = pbxproj_path.read_text(encoding='utf-8', errors='replace')

errors: list[str] = []
warnings: list[str] = []

def block_between(begin: str, end: str) -> str:
    m = re.search(re.escape(begin) + r"(.*?)" + re.escape(end), text, re.S)
    return m.group(1) if m else ""

# --- Project-level package references ---
project_pkg_refs: set[str] = set()
project_pkg_block = re.search(r"packageReferences\s*=\s*\(\s*(.*?)\s*\);", text, re.S)
if project_pkg_block:
    for line in project_pkg_block.group(1).splitlines():
        m = re.search(r"\b([0-9A-F]{24})\b", line)
        if m:
            project_pkg_refs.add(m.group(1))
else:
    warnings.append("No 'packageReferences' block found in PBXProject (no Swift packages declared at project level?)")

# --- Remote packages ---
remote_section = block_between("/* Begin XCRemoteSwiftPackageReference section */", "/* End XCRemoteSwiftPackageReference section */")
remote_pkgs: dict[str, str] = {}  # id -> repositoryURL
for m in re.finditer(r"\n\s*([0-9A-F]{24})\s*/\*.*?\*/\s*=\s*\{\s*\n\s*isa\s*=\s*XCRemoteSwiftPackageReference;(?P<body>.*?)\n\s*\};", remote_section, re.S):
    pkg_id = m.group(1)
    body = m.group('body')
    url_m = re.search(r"repositoryURL\s*=\s*\"([^\"]+)\";", body)
    remote_pkgs[pkg_id] = url_m.group(1) if url_m else ""

# Fail if any local package references exist.
if "XCLocalSwiftPackageReference" in text:
    errors.append("Found XCLocalSwiftPackageReference in project.pbxproj. Swift Packages must be remote.")

# Ensure project packageReferences only contain known remote packages (when present).
for pkg_id in sorted(project_pkg_refs):
    if pkg_id not in remote_pkgs:
        errors.append(f"PBXProject.packageReferences contains {pkg_id} which is not an XCRemoteSwiftPackageReference")

# Ensure all remote URLs are https.
for pkg_id, url in sorted(remote_pkgs.items()):
    if not url:
        errors.append(f"XCRemoteSwiftPackageReference {pkg_id} missing repositoryURL")
    elif not url.startswith("https://"):
        errors.append(f"XCRemoteSwiftPackageReference {pkg_id} repositoryURL is not https: {url}")

# --- Product dependencies ---
product_section = block_between("/* Begin XCSwiftPackageProductDependency section */", "/* End XCSwiftPackageProductDependency section */")
product_deps: dict[str, dict[str, str]] = {}  # id -> {package, productName}
for m in re.finditer(r"\n\s*([0-9A-F]{24})\s*/\*\s*([^*]+?)\s*\*/\s*=\s*\{\s*\n\s*isa\s*=\s*XCSwiftPackageProductDependency;(?P<body>.*?)\n\s*\};", product_section, re.S):
    dep_id = m.group(1)
    label = m.group(2).strip()
    body = m.group('body')
    pkg_m = re.search(r"package\s*=\s*([0-9A-F]{24})\b", body)
    prod_m = re.search(r"productName\s*=\s*([^;]+);", body)
    product_deps[dep_id] = {
        'label': label,
        'package': pkg_m.group(1) if pkg_m else "",
        'productName': (prod_m.group(1).strip() if prod_m else ""),
    }

declared_product_names = {info['productName'] for info in product_deps.values() if info.get('productName')}

def referenced_but_undeclared(product_name: str) -> bool:
    # Heuristic: keep it specific to Xcode's package product entries.
    patterns = [
        rf"/\*\s*{re.escape(product_name)}\s*\*/",
        rf"\bproductName\s*=\s*{re.escape(product_name)}\b",
        rf"{re.escape(product_name)}\s+in\s+Frameworks",
    ]
    return any(re.search(p, text) for p in patterns)

for must_have in ("Logging", "Collections"):
    if referenced_but_undeclared(must_have) and must_have not in declared_product_names:
        errors.append(
            f"'{must_have}' is referenced in the Xcode project but is not declared as an XCSwiftPackageProductDependency at the project level"
        )

# Each product dependency must point at a declared remote package that is listed in PBXProject.packageReferences.
for dep_id, info in sorted(product_deps.items()):
    if not info['package']:
        errors.append(f"XCSwiftPackageProductDependency {dep_id} ({info['label']}) missing 'package ='")
        continue
    if info['package'] not in remote_pkgs:
        errors.append(f"XCSwiftPackageProductDependency {dep_id} ({info['label']}) references non-remote package id {info['package']}")
    if project_pkg_refs and info['package'] not in project_pkg_refs:
        errors.append(f"XCSwiftPackageProductDependency {dep_id} ({info['label']}) package {info['package']} is not listed in PBXProject.packageReferences")
    if not info['productName']:
        errors.append(f"XCSwiftPackageProductDependency {dep_id} ({info['label']}) missing productName")

# --- Target package product deps ---
targets: dict[str, list[str]] = {}
# Greedy parse of PBXNativeTarget blocks: capture target id, then find name and packageProductDependencies list.
for m in re.finditer(r"\n\t\t([0-9A-F]{24})\s*/\*\s*([^*]+?)\s*\*/\s*=\s*\{\n\t\t\tisa\s*=\s*PBXNativeTarget;(?P<body>.*?)\n\t\t\};", text, re.S):
    body = m.group('body')
    name_m = re.search(r"\n\t\t\tname\s*=\s*([^;]+);", body)
    target_name = (name_m.group(1).strip() if name_m else m.group(2).strip())
    deps_m = re.search(r"packageProductDependencies\s*=\s*\(\s*(.*?)\s*\);", body, re.S)
    deps: list[str] = []
    if deps_m:
        for line in deps_m.group(1).splitlines():
            id_m = re.search(r"\b([0-9A-F]{24})\b", line)
            if id_m:
                deps.append(id_m.group(1))
    targets[target_name] = deps

# Validate each target's declared package product deps.
for target_name, dep_ids in sorted(targets.items()):
    for dep_id in dep_ids:
        if dep_id not in product_deps:
            errors.append(f"Target '{target_name}' links package product {dep_id} but no such XCSwiftPackageProductDependency exists")
            continue
        pkg_id = product_deps[dep_id]['package']
        if project_pkg_refs and pkg_id not in project_pkg_refs:
            errors.append(f"Target '{target_name}' links product '{product_deps[dep_id]['productName']}' from package {pkg_id}, but that package is not declared at project level")

# --- Framework build files that reference package products ---
# Ensure productRef build files refer to declared XCSwiftPackageProductDependency, and not weak-linked.
for m in re.finditer(r"\n\t\t([0-9A-F]{24})\s*/\*\s*([^*]+?)\s*\*/\s*=\s*\{\s*isa\s*=\s*PBXBuildFile;(?P<body>.*?)\};", text, re.S):
    body = m.group('body')
    pr_m = re.search(r"productRef\s*=\s*([0-9A-F]{24})\b", body)
    if not pr_m:
        continue
    product_ref = pr_m.group(1)
    if product_ref not in product_deps:
        errors.append(f"PBXBuildFile '{m.group(2).strip()}' references productRef {product_ref} but no such XCSwiftPackageProductDependency exists")
    if re.search(r"ATTRIBUTES\s*=\s*\([^)]*Weak[^)]*\)", body):
        errors.append(f"PBXBuildFile '{m.group(2).strip()}' weak-links a Swift package product (ATTRIBUTES contains Weak). Package products must not be optional.")

# Report
prefix = "[xcode-pkg-validate]"
for w in warnings:
    print(f"{prefix}[WARN] {w}")

if errors:
    for e in errors:
        print(f"{prefix}[ERROR] {e}")
    print(f"{prefix} FAIL: Swift package dependency integrity checks failed")
    sys.exit(1)

# Light summary (helps confirm what was validated)
print(f"{prefix} OK: {len(remote_pkgs)} remote packages, {len(product_deps)} products, {len(targets)} targets")
PY
