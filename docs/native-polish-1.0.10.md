# Native scenery polish 1.0.10

Four changes were reviewed with fixed native Gold cameras and daytime. JIFP
was disabled, so these changes belong entirely to the voxel renderer.

- Cherrygrove: water-bounded, non-water components containing native walkable
  cells become low rock platforms. The rule is explicitly scoped to
  CHERRYGROVE_CITY and capped at 64 cells. Blocked edge cells remain blocked;
  water, mainland cliffs and unwalkable sea rocks keep their existing shapes.
  The native player walked two cells on the island (5,13 to 7,13), showing
  standing/walking phases with support height 0–1, beside the native NPC.
- Small trees: remove 88 disconnected speck voxels from five native models
  (Johto, Modern, Kanto and the two Ilex variants). One bridge voxel joins the
  Ilex cut tree's existing trunk/canopy. Footprint, height and source texels
  remain native. No large-tree model changes.
- Pagodas: preserve all geometry in Sprout, Tin and Burned Tower models. Roof
  courses sample native dark/grey roofing rows instead of repeating the
  bright eave-underside row. Wall panels, doors, finials and other buildings
  retain their previous materials.
- Ranch fences: only connected native tile-74 north–south cells on ROUTE_39
  replace the old isolated standees with shared-endpoint rails and outlined
  posts. Posts remain within native collision cells; existing ground/skip
  bookkeeping and horizontal fence art are preserved. No new game collision.

The complete profile retains all 441 assets. Recovery input is
archive/voxel-profile-before-native-polish-1.0.9.lua. Reproduce with
tools/apply_native_polish.lua INPUT NEW_OUTPUT; it validates a full decoded
round-trip and replaces only the eight edited asset fields, preserving
unrelated source formatting. test_native_polish_preservation.lua compares
every decoded field against that baseline plus the two repairs. Never apply
this migration to the minimal fallback profile.

Tests: test_coastal_platforms, test_fence_rails, test_small_tree_cleanup,
test_pagoda_roof_materials, test_native_polish_preservation; existing mountain
shape/joins, terrain edges and live Cut-prop tests also pass. Physical mobile
performance is not measured.

Screenshots: exports/media/native-polish-1.0.10/ and the adjacent screenshot
ZIP in the workspace. Each comparison puts BEFORE left and AFTER right;
original full-resolution frames are included. The baseline driver injects
the saved old profile and disables only the two new scoped geometry rules.
workspace/tests/native_graphics_review_live.lua reproduces the captures;
REVIEW_BASELINE=1 selects old data, REVIEW_ONLY filters one target. Water
animation phase can differ. No ROM or player save is exported.
