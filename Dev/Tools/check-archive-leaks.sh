#!/bin/bash
# Archive Leak Detection - Prevents Docs/Archive from being compiled
# Usage: ./check-archive-leaks.sh
# Exit code: 0 if clean, 1 if leaks found

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PBXPROJ="$ROOT_DIR/webOS.xcodeproj/project.pbxproj"

echo "🔍 Scanning for Docs/Archive leaks in pbxproj..."

# Check 1: Archive files in Sources build phase
ARCHIVE_IN_SOURCES=$(grep -c "Docs/Archive.*\.swift" "$PBXPROJ" 2>/dev/null || true)
if [ "$ARCHIVE_IN_SOURCES" -gt 0 ]; then
    echo "❌ FAIL: Found $ARCHIVE_IN_SOURCES .swift files from Docs/Archive in pbxproj"
    grep -n "Docs/Archive.*\.swift" "$PBXPROJ"
    exit 1
fi

# Check 2: Archive paths in PBXSourcesBuildPhase
if grep -A 50 "PBXSourcesBuildPhase" "$PBXPROJ" | grep -q "Docs/Archive"; then
    echo "❌ FAIL: Docs/Archive detected in PBXSourcesBuildPhase"
    exit 1
fi

# Check 3: Archive paths in PBXResourcesBuildPhase
if grep -A 50 "PBXResourcesBuildPhase" "$PBXPROJ" | grep -q "Docs/Archive"; then
    echo "❌ FAIL: Docs/Archive detected in PBXResourcesBuildPhase"
    exit 1
fi

# Check 4: Archive paths in PBXCopyFilesBuildPhase
if grep -A 50 "PBXCopyFilesBuildPhase" "$PBXPROJ" | grep -q "Docs/Archive"; then
    echo "❌ FAIL: Docs/Archive detected in PBXCopyFilesBuildPhase"
    exit 1
fi

# Check 5: Dev/Tools/_legacy in any build phase
LEGACY_IN_BUILD=$(grep -E "Dev/Tools/_legacy.*\.(swift|h|m)" "$PBXPROJ" 2>/dev/null | grep -E "(Sources|Resources|Frameworks)" | wc -l)
if [ "$LEGACY_IN_BUILD" -gt 0 ]; then
    echo "❌ FAIL: Found Dev/Tools/_legacy files in build phases"
    exit 1
fi

echo "✅ PASS: No archive leaks detected"
echo "   - Docs/Archive: not in pbxproj ✓"
echo "   - Dev/Tools/_legacy: not in pbxproj ✓"
exit 0
