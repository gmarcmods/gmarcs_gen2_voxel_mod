# Native Kanto roofs — 1.0.6

This replaces the incorrect 1.0.5 hip/pyramid roof treatment. The maintained
Gen 1 renderer is the reference: `Buildings.measure/model` measures the first
drawn pixel in each roof column, including the actual sprite ground line,
and lays the roof through the building depth. The native taper creates the
sloped ends; the central roof remains level. Roof rows are depth, not a second
storey of height. Rim pixels map once at the front/back; the interior repeats
the native material course instead of stretching silhouettes across slopes.

`lib/SpriteRoof.lua` applies those rules to the thirteen authored Kanto house
roofs. The old roof voxels are removed, not covered. The authored facade,
recessed doors/windows, rear/side materials, ground placement, IDs and matching
grids remain. Walls are trimmed beneath the roof, as in Gen 1, so they cannot
poke through the sloping ends. Window-sill protrusions do not enlarge the
roof footprint. Commercial flat roofs and all unrelated assets are unchanged.

Verification:

- `luajit tests/test_sprite_roof.lua` compares roof lookups directly with the
  maintained Gen 1 algorithm, including ground-row and protruding-sill cases.
- `luajit tests/test_kanto_roof_slopes.lua /tmp/kanto-roofs-1.0.5.lua`
  checks recipe agreement, absence of the old roof and preservation of the
  other 441-asset project data against the previous release.
- `tests/kanto_roofs_live.lua` compares every roof voxel against Gen 1 using
  actual native Kanto sprite pixels for all thirteen roofs. It also captures
  front/back views of small/large Celadon houses, the Fuchsia house and Pewter
  museum with the first-person companion detached. Captures were inspected.

The Gen 1 mod itself is unchanged. Validation is desktop Gold; no physical
Android test was performed. The renderer is common to Gold, Silver and Crystal.
The 1.0.5 screenshots remain historical references; current captures are named
`docs/screenshots/kanto-roofs-1.0.6-*`.
