# Terrain, actors and furniture — 1.0.4

Cave platform caps now distinguish native side walls (0xb0–0xb7) from actual
jump ledges (0xa0–0xa7). Solid north caps retain the 16px platform height;
shores and the five native low-jump blocks stay low.

Native waterfall footprints produce a 48px drop, a raised upstream basin
and containing rock. Waterfalls retain their vertical scrolling texture.
The atlas now also runs native whirlpool, lava and tower-pillar frame strips,
using the native animation timer and palettes. This reuses the existing
shader/atlas pass; no particle system or extra per-cell draw calls were added.

Elite Four stair templates mark their entire authored footprint as unsuitable
for battle actors. Indoor arenas use the short wide lens so the eye stays
inside the room instead of viewing a wall from outside. Elite voids descend
32px and retain continuous sides without overlapping the indoor floor skirt.

Tin Tower's roof rises toward its 48px walking ridge; the stairs and actors
use that same support height. Kanto houses have hip slopes, flat-roof buildings
have a small edge bevel, and rear/side walls sample native wall/foundation
texels. Original facade/window art and the Lavender tower's height remain.
Route 6 uses visible four-pixel curbs and four-tread access gaps. Cycling Road
keeps continuous camera-relative riding; idle downhill drift remains southward
and A/B brake it through the native Gen 2 bike state.

Big Snorlax/Lapras use all four native sprite quarters, valid triangle indices
and the center of their two-cell footprint in both solid/shadow passes.
Silph reception is 8px high. Celadon workdesks have complete CRT fronts and
supported tables/chairs. The sprite formerly modeled as a filing cabinet is
actually a bed: it now lies horizontally on legs. Its historical asset ID is
retained for compatibility.

All 441 authored assets remain. `tests/authored_repair_preservation.lua` checks
unrelated assets, classes and tile assignments against the 1.0.3 profile. The
new profile SHA256 is
`3a12af3449ec5b0fe200c9f4e6596bc9f86cf2aa0bf7d572f90cd437f294e3af`.

## Verification

Run the focused `tests/test_{cave_surfaces,gen2_water_animation,big_sprite,
waterfall_terrain,battle_stair_clearance,room_geometry,tin_tower_pits}.lua`
files individually with LuaJIT. The Tin Tower test also accepts a native
`data/generated` directory and checks Gold/Silver/Crystal jump directions.

Live Gold drivers: `terrain_repair_probe.lua` renders the reported maps and
asserts changing GPU atlas pixels; `elite_battle_visibility_live.lua` opens all
five real trainer battles and captures trainers/Pokémon;
`cycling_camera_live.lua` checks twelve first/third-person headings.
Selected captures are in `docs/screenshots/repair-1.0.4-*`.

The workspace copies relevant runtime fixes to the fallback/editor repo too.
Johto First Person's presentation source is unchanged. These are desktop LÖVE
checks, not physical Android measurements.
