# STEP 1: LEGACY IDENTIFICATION REPORT

**Status:** ✅ COMPLETE  
**Date:** January 8, 2025

---

## LEGACY INVENTORY

### GROUP A: Legacy NOT in target (safe to move immediately)

Can be relocated without touching pbxproj.

#### A1: Documentation & Reports in Docs/
These are process/analysis docs (not architectural docs):
- `Docs/BATCH_1_DELETION_PLAN.md` (deletion process tracking)
- `Docs/INVENTORY_CLASSIFICATION.md` (cleanup analysis)
- `Docs/PBXPROJ_CLEANUP_REPORT.md` (cleanup execution report)
- `Docs/CLEANUP_REPORT.md` (initial cleanup report)

**Why Legacy:** Progress reports, intermediate analysis, not needed for ongoing maintenance

**Recommendation:** Move to `Docs/Archive/Process/`

---

#### A2: Configuration Documentation in SafariLikeKit/Config/
These are investigation/verification docs (not code):
- `SafariLikeKit/Config/DEVELOPER_CHECKLIST.md` (task tracking)
- `SafariLikeKit/Config/PUBLIC_API_LOCK.md` (API verification)
- `SafariLikeKit/Config/PUBLIC_API_QUICK_REFERENCE.md` (API reference)
- `SafariLikeKit/Config/PUBLIC_API_VERIFICATION.md` (verification results)
- `SafariLikeKit/Config/PUBLIC_API_WORK_SUMMARY.md` (work summary)
- `SafariLikeKit/Config/PublicAPI_ALLOWLIST.md` (allowlist)
- `SafariLikeKit/Config/README_PUBLIC_API.md` (readme)

**Why Legacy:** API investigation docs, not active code, developer checklists

**Recommendation:** Move to `Docs/Archive/PublicAPI/`

---

#### A3: Deprecated Code File
- `SafariLikeKit/Core/LegacyPluginManagerImpl.swift`

**Content:** Active PluginManager implementation code (NOT deprecated despite name)  
**Status:** NOT in pbxproj target (file not compiled)  
**Impact:** Zero (file orphaned)  
**Analysis:** Appears to be intentionally left behind, not imported anywhere

**Why Legacy:** Named "Legacy", not in build, orphaned  
**Recommendation:** Move to `Dev/Tools/_legacy/`

**Note:** This file is ACTIVE CODE but ORPHANED - interesting case

---

#### A4: Readme Files in Framework/Config
- `SafariLikeUIKit/README.md` (framework overview)
- `SafariLikeUIKit/REUSABILITY_GUIDE.md` (API guide)
- `SafariLikeUIKit/REUSABILITY_PREPARATION_COMPLETE.md` (completion report)
- `SafariLikeUIKit/REUSABILITY_VERIFICATION.md` (verification report)
- `SafariLikeUIKit/IMPORT_AUDIT.md` (import audit)
- `SafariLikeKit/Core/OS/README_Phase1.md` (phase report)

**Why Legacy:** Work-in-progress reports, verification docs, not architectural

**Recommendation:** Move to `Docs/Archive/Framework-Reports/`

---

### GROUP B: Legacy still in target (must detach before moving)

Files that are referenced in pbxproj but should not be:
```
SEARCH RESULT: 0 files found in target
```

✅ **Verification:** No legacy files are currently in the build target.

---

### GROUP C: Ambiguous (needs further analysis)

Files with unclear status:

#### C1: SafariLikeKit/Core/LegacyPluginManagerImpl.swift
- Named "Legacy" but appears to be active code
- Not in pbxproj target (so not compiled)
- Not imported anywhere (so dead code)
- **Decision:** Move to Dev/Tools/_legacy with analysis note

---

## SUMMARY TABLE

| Group | Count | Examples | In-Target? | Action |
|-------|-------|----------|-----------|--------|
| **A** | 17 | BATCH_1_*.md, PUBLIC_API_*.md, LegacyPluginManager, READMEs | ❌ NO | Move to Archive |
| **B** | 0 | — | — | — |
| **C** | 0 | — | — | — |

---

## RELOCATION PLAN

### New Archive Structure

```
Docs/
├── ARCHITECTURE.md              (KEEP - primary architecture)
├── PluginSystem.md              (KEEP - active feature guide)
├── SafariLikeKit.md             (KEEP - active framework doc)
├── README_PROJECT.md            (KEEP - project overview)
│
└── Archive/
    ├── Process/
    │   ├── BATCH_1_DELETION_PLAN.md
    │   ├── INVENTORY_CLASSIFICATION.md
    │   ├── PBXPROJ_CLEANUP_REPORT.md
    │   └── CLEANUP_REPORT.md
    │
    └── Framework-Reports/
        ├── PublicAPI/
        │   ├── PUBLIC_API_LOCK.md
        │   ├── PUBLIC_API_QUICK_REFERENCE.md
        │   ├── PUBLIC_API_VERIFICATION.md
        │   ├── PUBLIC_API_WORK_SUMMARY.md
        │   ├── PublicAPI_ALLOWLIST.md
        │   └── README_PUBLIC_API.md
        │
        ├── SafariLikeUIKit/
        │   ├── README.md
        │   ├── REUSABILITY_GUIDE.md
        │   ├── REUSABILITY_PREPARATION_COMPLETE.md
        │   ├── REUSABILITY_VERIFICATION.md
        │   └── IMPORT_AUDIT.md
        │
        └── Phase1/
            └── README_Phase1.md
```

```
Tools/
├── package.json              (KEEP - build tool)
├── package-lock.json         (KEEP - build tool)
├── server.js                 (KEEP - dev server)
│
└── _legacy/
    └── LegacyPluginManagerImpl.swift
```

---

## FILES NOT IN TARGET (NO DETACHMENT NEEDED)

All 17 legacy files are **NOT in the Xcode project target**:
- ✅ Not in PBXSourcesBuildPhase
- ✅ Not in PBXResourcesBuildPhase
- ✅ Not in any Build Phase
- ✅ Can be moved without pbxproj changes

---

## NEXT STEP

→ **STEP 3: Execute Safe Relocation**
- Create archive folder structure
- Move 17 legacy files
- Update pbxproj PBXGroup structure (optional, non-critical)
- Verify no broken references

---

**This analysis is conservative and safe:**
- We preserve active code and framework documentation
- We archive process/work reports and investigation docs
- We don't touch pbxproj BuildPhases (no changes needed)
- Zero risk of breaking builds or runtime behavior
