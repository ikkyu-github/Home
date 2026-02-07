#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT_DIR"

echo "[pkg-validate] repo: $ROOT_DIR"

if [[ ! -d "RuntimePackages" ]]; then
  echo "[pkg-validate] OK: no RuntimePackages directory" 
  exit 0
fi

# Forbidden directories anywhere inside a Swift package.
FORBIDDEN_DIR_NAMES=(
  ".build"
  "build"
  "DerivedData"
  "xcuserdata"
  ".swiftpm"
)

# Forbidden generated/compiled file globs inside a Swift package.
FORBIDDEN_FILE_GLOBS=(
  "*.pcm"
  "*.swiftmodule"
  "*.swiftdeps"
  "*.swiftdoc"
  "*.swiftinterface"
  "*.dia"
  "*.d"
  "*.timestamp"
  "*.o"
  "*.a"
  "*.dylib"
  "*.so"
  "*.xcactivitylog*"
)

# Forbidden bundle/compiled directories.
FORBIDDEN_DIR_SUFFIXES=(
  ".xcframework"
  ".framework"
  ".xcresult"
  ".dSYM"
)

fail=0

# Enumerate package roots (directories that contain Package.swift)
while IFS= read -r pkg_swift; do
  pkg_dir="$(dirname "$pkg_swift")"
  pkg_rel="${pkg_dir#./}"

  echo "[pkg-validate] package: $pkg_rel"

  # 1) Fail if Package.swift declares binary targets (source-only requirement).
  if grep -Eq "\\bbinaryTarget\\s*\\(" "$pkg_swift"; then
    echo "[pkg-validate][ERROR] $pkg_rel/Package.swift declares a binaryTarget; packages must be source-only." >&2
    fail=1
  fi

  # 2) Fail if forbidden directories exist.
  for name in "${FORBIDDEN_DIR_NAMES[@]}"; do
    if find "$pkg_dir" -type d -name "$name" -print -quit | grep -q .; then
      echo "[pkg-validate][ERROR] $pkg_rel contains forbidden directory '$name'" >&2
      find "$pkg_dir" -type d -name "$name" -print | sed 's|^|  - |' >&2
      fail=1
    fi
  done

  for suf in "${FORBIDDEN_DIR_SUFFIXES[@]}"; do
    if find "$pkg_dir" -type d -name "*${suf}" -print -quit | grep -q .; then
      echo "[pkg-validate][ERROR] $pkg_rel contains compiled bundle directory '*${suf}'" >&2
      find "$pkg_dir" -type d -name "*${suf}" -print | sed 's|^|  - |' >&2
      fail=1
    fi
  done

  # 3) Fail if forbidden file types exist.
  for glob in "${FORBIDDEN_FILE_GLOBS[@]}"; do
    if find "$pkg_dir" -type f -name "$glob" -print -quit | grep -q .; then
      echo "[pkg-validate][ERROR] $pkg_rel contains forbidden file(s) matching '$glob'" >&2
      find "$pkg_dir" -type f -name "$glob" -print | sed 's|^|  - |' >&2
      fail=1
    fi
  done

done < <(find ./RuntimePackages -name Package.swift -type f -print | sort)

if [[ "$fail" -ne 0 ]]; then
  echo "[pkg-validate] FAIL: one or more Swift packages contain build/cache/compiled artifacts" >&2
  echo "[pkg-validate] Hint: delete the artifacts and rebuild using Dev/Tools/Scripts/spm.sh (external scratch path)." >&2
  echo "[pkg-validate] Note: if '.build/index-build' keeps reappearing, configure SourceKit-LSP to use an external --scratch-path (see Docs/REPO_HYGIENE.md)." >&2
  exit 2
fi

echo "[pkg-validate] OK: all Swift packages are source-only (no build artifacts found)"
