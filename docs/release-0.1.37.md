# 0.1.37

Ships runtime 1.10.26: immediate Cut tree visibility and native regrowth,
third-person Surf camera clearance, and the Persian statue repair.

Only `TILESET_UNDERGROUND / underground_statue` changes in the authored
profile. Its feline anatomy and bevelled pedestal occupy the southern native
collision cell instead of the projected northern sprite cell. The native
sprite remains the source of its colors. All 441 assets and unrelated profile
values are preserved; the old profile is retained in
`archive/voxel-profile-before-persian-0.1.36.lua` at the workspace root.

Runtime tests include an idempotent recipe, complete profile comparison,
collision bounds and a live Gold hideout/Surf probe. Cut/regrowth was checked
live on Gold/Silver/Crystal; Gold Route 32 also covers the outdoor tileset.
The separate JIFP presentation companion is unchanged. Physical Android was
not tested for these fixes.
