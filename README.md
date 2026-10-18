# Complete authored Gen 2 voxel project

Install NEW_MOD_EX.zip. This project contains all 392 authored assets; runtime
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
