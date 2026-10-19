# Tin Tower jump pits (1.0.3)

Tin Tower floors 2–9 use the dark lattice as recessed shaft artwork. It was
classified as raised tower walls/roof, making the jump maze look like solid
blocks above the paths. `TinTowerInterior` now resolves those native tiles
below the walking floor, with a continuous dark bottom 32 pixels below it.
The original dark timber artwork textures the exposed platform cliff faces.

Native white ledge tiles become short voxel launch ramps: four two-pixel
bands rise from floor level to three pixels. Their left/right/south direction
comes from the neighbouring native COLL ledge cell, including corner cells
that permit two directions. Texture coordinates remain in the source sprite's
orientation. The ramp claims replace the old extrusion without synthesizing
a solid floor underneath the gap.

This is renderer geometry only. Native blocks, collision, jump rules, warp
locations, authored furniture and the complete profile remain unchanged.
Tin Tower 1F, Sprout Tower, Burned Tower and other shared-tileset rooms retain
their previous shapes. The active authored project currently owns tracked
renderer files; the matching runtime/editor implementation is kept in sync.

Validation:

- `luajit mods/gen2/new_mod_ex/tests/tin_tower_pits.lua` from the workspace.
- Pass a decoded `data/generated` directory as its first argument to verify
  every native jump direction on all eight floors. This passed for Gold,
  Silver and Crystal, including double-direction ledges.
- `tests/tin_tower_jump_probe.lua` runs the active renderer in-game, asserts
  real pit heights and ramp presence, and captures matched overview and close
  camera views. Desktop Gold 3F, 4F and 5F were rendered and inspected.

The authored profile SHA256 remains
`9d596986eaf9f10ae0682d2fd9f1882bab50acc75182c8cdec367193dc175993`.
This review did not use a physical Android device.
