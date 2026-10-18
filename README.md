# Complete authored Gen 2 voxel project

Install NEW_MOD_EX.zip. This project contains all 392 original authored assets plus the native Ilex cut-tree, two sea-rock models and eighteen mall fixture patterns; runtime
code is shared through relative links to ../voxel-runtime. Never replace its
data/voxel_heights.lua with the runtime's minimal fallback.

Version 0.1.17 corrects gym sculpture collision placement, Sprout Tower's
Bellsprout statues, cuttable trees and gym pits. Shared runtime 1.10.10 fixes
building-front self-shadow artifacts and trainer marker projection. Changes
are independent of Johto in First Person.

Validation and migration tools live in ../voxel-runtime/tests and tools.
Run test_detail_repairs.lua from that repository (or by its full path) to
compare unrelated authored assets against the 0.1.16 recovery baseline.
Package from the workspace root with scripts/export-mods.py NEW_MOD_EX.

Version 0.1.19 rebuilds Kurt’s tables, cabinets and workbench tools, rounds the
Slowpoke Well entrance, and models Ilex’s native cut tree and outer tree ring.
Runtime 1.10.12 adds bounded native cave rock detail without editing collision.

Version 0.1.20 aligns both Ilex gatehouse hulls with their native collision
footprints and keeps the north and west entrance cells open.

Version 0.1.21 makes the small Johto sea rocks solid, rounded and low,
with animated water beneath them. All 393 previous assets are retained.

Version 0.1.22 rebuilds department-store shelves, displays, seating, counters,
windows, elevator fixtures and basement crates. All 395 previous assets are
retained; eighteen additional fixture patterns bring the total to 413.

Version 0.1.23 details Goldenrod’s tower facade, dishes and antenna lattice,
and both Radio Tower interiors’ desks, phones, CRTs, studio equipment, drawers
and framed glass. Fourteen reception modules bring the inventory to 427.
