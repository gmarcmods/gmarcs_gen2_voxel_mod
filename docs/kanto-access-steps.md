# Kanto ledge access steps

The Route 6-only access-gap mesher now applies to the Kanto tileset. Native
tile 4 is a walkable opening in a low ledge: it receives four two-pixel treads,
with one-pixel risers, rather than the same flat/extruded treatment as tile 55.
Treads preserve their corresponding rows of the native opening art; darker
risers separate them. The low jump border is four pixels high to meet the top.

Tile 55 used as a solid cliff retains its height and material. Native cliff
corner tile 52 is no longer lowered by the old Route 6 special case. Solid
cells and cells claimed by authored objects cannot become stair openings.
No gameplay collision, map blocks, warps or authored asset data are changed.

`tests/test_kanto_access_steps.lua` covers routes, towns, solid cliffs,
unwalkable cells, claimed cells and isolation from other tilesets.
`tests/test_room_geometry.lua` also checks the original Route 6 behavior.

The live Gold survey (`tests/kanto_access_live.lua`) found 126 opening tiles
on 21 maps and verified four treads at every opening. It captured angled and
eye-level views on Route 3, 4, 6, 9, 22, Pewter, Cerulean and Viridian.
The close views were inspected; selected examples are in `docs/screenshots/`.
This is desktop validation, not a physical Android test.
