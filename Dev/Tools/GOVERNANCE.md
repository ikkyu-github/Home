# Repository Governance & Archive Protection

This directory contains tools and hooks to maintain repository integrity and prevent archived code from leaking into the build.

## Files

### `check-archive-leaks.sh`
Scans `webOS.xcodeproj/project.pbxproj` for any references to archived files in build phases.

**Usage:**
```bash
./Dev/Tools/check-archive-leaks.sh
```

**Output on PASS:**
```
✅ PASS: No archive leaks detected
   - Docs/Archive: not in pbxproj ✓
  - Dev/Tools/_legacy: not in pbxproj ✓
```

**Output on FAIL:**
```
❌ FAIL: Found X .swift files from Docs/Archive in pbxproj
[shows which files leaked]
```

### `GitHooks/pre-commit`
Git pre-commit hook that blocks commits if archived files are accidentally added to build phases.

**Installation:**
```bash
./Dev/Tools/Scripts/install_git_hooks.sh
```

Once installed, any attempt to commit archived files in pbxproj will be rejected:
```
❌ BLOCKED: Cannot commit - Docs/Archive .swift files detected in pbxproj
```

## Archive Protection Layers

### Layer 1: Project Configuration (Xcode)
- ✅ `Docs/Archive/*` files are NOT in pbxproj targets
- ✅ `Dev/Tools/_legacy/*` files are NOT in pbxproj targets
- Verified by: `check-archive-leaks.sh`

### Layer 2: Build Phases (Compile-time)
- ✅ No archive files in `PBXSourcesBuildPhase`
- ✅ No archive files in `PBXResourcesBuildPhase`
- ✅ Marker file `Docs/Archive/_DO_NOT_USE/DO_NOT_USE.swift` will fail build if accidentally added
- Verified by: `check-archive-leaks.sh`

### Layer 3: Git Hooks (Commit-time)
- ✅ Pre-commit hook prevents committing archive files in pbxproj changes
- Verified by: `.githooks/pre-commit`

### Layer 4: Developer UX (Runtime)
- ✅ Archive README explains rules (`Docs/Archive/README.md`)
- ✅ Root README links to archive documentation (`../README.md`)
- ✅ Architecture docs point to active frameworks, not archive

## Verification Workflow

### Before Committing Code Changes:
```bash
# 1. Check for archive leaks
./Dev/Tools/check-archive-leaks.sh

# Expected:
# ✅ PASS: No archive leaks detected
```

### After Modifying pbxproj in Xcode:
```bash
# 1. Check for accidental archive references
./Dev/Tools/check-archive-leaks.sh

# 2. Verify build still passes
xcodebuild clean && xcodebuild -scheme webOS build
```

### If You See a Build Error:
```
#error("Archived code detected. This file is NOT part of the active build...")
```

**Fix:**
1. Find the offending file in Xcode
2. Uncheck "Target Membership" for that file
3. Remove from build phases in pbxproj
4. Run `./Dev/Tools/check-archive-leaks.sh` to verify fix
5. Run build again

## Automated Checks (Optional CI/CD)

If using GitHub Actions or similar CI:

```yaml
# .github/workflows/archive-protection.yml
name: Archive Protection Check
on: [pull_request]
jobs:
  check-archive:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - run: ./Dev/Tools/check-archive-leaks.sh
```

## Archive Structure

```
Docs/Archive/
├── README.md                    # Archive rules & guidelines
└── _DO_NOT_USE/                 # All archived files prefixed with _
    ├── DO_NOT_USE.swift         # Safety marker (fails if compiled)
    ├── Process/                 # Cleanup process documentation
    │   ├── BATCH_1_DELETION_PLAN.md
    │   ├── INVENTORY_CLASSIFICATION.md
    │   ├── PBXPROJ_CLEANUP_REPORT.md
    │   └── CLEANUP_REPORT.md
    └── Framework-Reports/       # Legacy framework documentation
        ├── Phase1/
        ├── PublicAPI/
        └── SafariLikeUIKit/

Dev/Tools/_legacy/
└── LegacyPluginManagerImpl.swift # Orphaned code (not in pbxproj)
```

## Troubleshooting

### Q: "I want to reuse code from Archive"
**A:** 
1. Read `Docs/Archive/_DO_NOT_USE/Framework-Reports/` for the design
2. Don't copy code - understand the pattern
3. Reimplement in the active framework
4. Reference your implementation, not the archived one

### Q: "Archive file was accidentally added to Xcode"
**A:**
1. Open `webOS.xcodeproj` in Xcode
2. Find the file in the project navigator
3. Delete it (don't delete file on disk)
4. Run `./Tools/check-archive-leaks.sh` to verify
5. Commit the pbxproj changes

### Q: "Pre-commit hook blocks my commit"
**A:**
1. Run `./Tools/check-archive-leaks.sh` to see what's wrong
2. Fix the pbxproj (remove archive file references)
3. Try commit again

### Q: "How do I bypass the pre-commit hook?"
**A:** 
Don't. It's protecting the repo. Fix the issue instead:
```bash
# See what's wrong
./Tools/check-archive-leaks.sh

# Fix it in Xcode or manually in pbxproj

# Try commit again
git commit ...
```

---

**Maintained by:** Repository Governance System  
**Last Updated:** January 8, 2026
