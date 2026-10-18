# 0.1.39 — native statue audit

Repairs six guardian-statue variants, including the Fighting Dojo pedestal
alignment, and restores Violet's square carvings and Blackthorn's dragon
crest as native-art stone reliefs. These eight model changes cover 65 native
Gold placements. The 0.1.38 Persian, Bellsprout and Poké Ball sculptures remain
unchanged. All 441 authored assets and unrelated fields are preserved.

The runtime owns the common authoring recipe and audit tests. All 13 variants
were inspected on native maps with front/oblique views; all 109 placements
across 28 Gold maps passed collision checks. The preserved baseline is
`archive/voxel-profile-before-statue-audit-0.1.38.lua` in the workspace.
Earlier Cut, Surf, menu-independent voxel fixes remain included.
