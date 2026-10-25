# Cherrygrove native rock terraces

The three blocked 4×4-tile formations in Cherrygrove retain a raised 8-pixel rocky terrace above the walking platform. Their exact native tile matrix and nonwalkable collision cells must match before the replacement is used. Other maps and mainland cliffs keep their existing geometry.

The flat cap uses native Johto tile 60, the speckled interior ground. The southern stone border is unfolded once onto each side at native pixel scale; the sprite’s baked eastern dithered shadow is not used as rock material. Narrow shoulders use the same ground material; stone border pixels belong on vertical faces. Collision data is unchanged.

Geometry is editable in `tools/asset_recipes/coastal/cherrygrove-terrace.voxel.json`; run the adjacent `build_terrace.py` to reproduce the Lua data. The three placements reuse one cached static mesh (6,888 occupied voxels, 1,956 quads), without an additional actor render pass.

Validation: `tests/test_coastal_terraces.lua`, `tests/test_terrace_materials.lua` and the workspace `native_graphics_review_live.lua` Gold driver. Native captures cover front, side, back, overhead and walking. This is desktop validation, not a physical mobile performance measurement.
