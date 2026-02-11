# Refactor Roadmap Update (Executable PR Plan)

All rationale items must be traceable to evidence links (TODO lines or cross-reference hits).

## PR 1 — Baseline: add analysis artifacts

- Rationale: make full inventory + evidence maps reviewable before any edits
- Files touched: [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP3_cross_reference_maps_A-E.md](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP3_cross_reference_maps_A-E.md), [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP4_overlap_dead_code_audit.md](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP4_overlap_dead_code_audit.md), [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP5_incomplete_features_report.md](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP5_incomplete_features_report.md)
- Acceptance: artifacts exist and cover all Swift files
- Verification checklist:
  - Confirm Step 1 count in [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP1_file_inventory_GROUPED.md](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP1_file_inventory_GROUPED.md)
  - Spot-check 10 random files: types/functions present in Step 2 CSV
- Rollback: delete Dev/Reports/SwiftWorkspaceIndex_2026-02-11

## PR 2 — Layout/orientation contract consolidation (UNVERIFIED until design review)

- Rationale: decision points scattered across files (see STEP3 section B/C)
- Evidence: [Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP3_cross_reference_maps_A-E.md](Dev/Reports/SwiftWorkspaceIndex_2026-02-11/STEP3_cross_reference_maps_A-E.md) (B_*, C_*)
- Anchor example (critical TODO): [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/RelatedPresentationPolicy.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/RelatedPresentationPolicy.swift#L23)
- Files touched: UNVERIFIED (depends on which decision points become authoritative)
- Acceptance tests / verification:
  - Run webOSUITests rotation regression suite
  - Manual: rotate in split-pane + tab switching + keyboard showing
- Rollback strategy: revert PR; keep artifacts

