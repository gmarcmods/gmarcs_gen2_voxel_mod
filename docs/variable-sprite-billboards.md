# Variable-size sprite billboards

The renderer uses native SpriteRenderer pose geometry for custom frames, anchors, grid sheets and display scaling. Quad viewports are authoritative for texture coordinates. Visible, occlusion and shadow passes share one pose snapshot per scene frame. Native 16×16 sprites retain a cached fast path. Large sprites still use one textured quad; no pixel meshes, resampled textures or additional actor draw passes are introduced. Native multi-part Snorlax/Lapras retain their existing reconstruction.

`mod.exports.supportsVariableSpriteGeometry = true` advertises this contract. Integrations should discover the actual renderer ID (`gmarcs_gen2_voxel_mod`, or `GEN2_VOXEL` for the fallback), rather than impersonating another renderer.

Verified with unmodified Wilds of Kanto Revival 2.8.6 in Gold: classic and HG/SS followers, voxel off/on, Charizard (32×32) and Onix (35×38), with full texture frames and matching shadows. Revival currently does not list our Gen 2 renderer IDs in its discovery list; its true-size output nevertheless renders correctly through this native geometry support. Upstream can add those IDs and consume the exported capability without a renderer-specific patch.

Checks: `luajit tests/test_variable_sprite_billboards.lua` and `luajit tests/test_big_sprite.lua`. The first covers anchors, scale, grid viewports, shared pose snapshots, animated geometry invalidation and allocation-free native geometry lookup after warmup. It does not measure GPU time or physical Android performance. Live driver: `workspace/tests/wilds_voxel_compat_live.lua` from the workspace root, using isolated imported data and no save writes.
