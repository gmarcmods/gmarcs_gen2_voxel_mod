# Additive region profiles (API 1)

The authored renderer exposes `mod.find('gmarcs_gen2_voxel_mod').exports.profileExtensions`.
A separate companion registers its own region assets; it never patches renderer
files, replaces `data/voxel_heights.lua`, or injects first-person effects.

```lua
local api = assert(mod.find('gmarcs_gen2_voxel_mod')).exports.profileExtensions
assert(api.apiVersion == 1)
api:register('MY_REGION', {
  schema = 'voxel.extension.v1', tilesetPrefix = 'MYREGION_', classPrefix = 'myregion_',
  classes = { myregion_low = { base = 'wall', height = 8, art = 'top' } },
  tilesets = { MYREGION_ROOM_TILES = { myregion_low = { 12 } } },
  buildings = {},
})
-- Replacing the same registration is atomic; removing it restores base data.
api:remove('MY_REGION')
```

`register(id, spec)` validates the entire candidate composition before committing
it. Exceptions leave the old profile active. Prefixes must end in `_`. Classes
must have the class prefix and pass `ClassDefinitions`; pins name known classes.
An extension may add only previously unowned tileset IDs. It cannot modify a base
or another extension's class, tileset, or asset list. Tiles cannot be pinned to
two classes. Registered data is copied so the caller cannot accidentally mutate
it afterward. Native profile branches are shared as immutable data, avoiding a
copy of the 39 MB authored profile for each companion. Loading that profile
remains lazy when the API/voxel renderer is unused.

Building assets use the existing `tiles`, optional `topRows`, `map`, `groundTile`,
nonempty `surfaces`, and `voxelEdits` format. Coordinates/source indices are
validated before `AssetSurface.build` rather than silently clamped. Optional
`cutFloor` enables below-floor holes; `support` declares a standee support height.
Asset occupancy is capped at 65,536 voxels and surface generation at one million
candidates. Source texel index zero remains valid. The API invalidates the shape,
structure and chunk caches after successful registration/removal.

`list()` returns sorted registration IDs. `current()` exposes the composed
profile for read-only diagnostics; consumers must not mutate its tables.
The editor's deliberate whole-profile injection remains separate.

The workspace's `tools/voxels/workshop.py` compiles compact recipes into this
format, packs arithmetic voxel runs, validates against this actual renderer,
and builds a companion with no renderer copy. Its generated helper checks the
region's `renderBinding` before registering and exposes `attach()` / `remove()`
for reversible review. The runtime API does not infer gameplay collision.

Validation: `luajit tests/test_profile_extensions.lua .`. The workspace live
probe checks a separate Hoenn table addon, native class resolution, five camera
views, detach/reattach and preservation of all 441 authored native assets.

## New terrain and border models

Tileset entries accept class pins together with validated native settings:
`heights`, `art`, `when_above`, `when_below`, `terrain_edges`, `mountain`,
`border_blocks`, `prop_ground`, `prop_bg`, `bookcase_relief`, and
`bookcase_backfill`. `planter_spray=false` disables the native heuristic;
omit the field for its default. Terrain/mountain validation reuses the actual
renderer modules, and contextual rules must reference known classes/tiles.
These settings apply only to the extension's new tilesets.

Authored assets can set `border=true` and explicitly `lodTree=true` to reuse the
existing distant-border-tree LOD. A coarse mesh is used only beyond the near
32px filler band and only when it reduces quads. Native tree-name eligibility
is unchanged; furniture is never auto-classified as a tree.
