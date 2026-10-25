# Johto mountain border materials

Johto cliffs and plateaus now separate native ground from the stone edge drawing. Tile 60 supplies the horizontal cap. Tile 76 supplies the upper eight pixels of an exposed vertical face exactly once; taller rock continues with tile 54 rows 2–7, excluding its horizontal rim. Native pixel density is preserved, including partial faces. Baked east-edge dither shadows are no longer used as cap art.

Scoped to TILESET_JOHTO mountain classes and the reviewed Cherrygrove walking platform. Other tilesets, furniture, height fields, collision and map joins retain existing definitions. Narrow Cherrygrove terrace shoulders also use ground. Terrain still uses the existing stepped height field; mountain elevations are not redesigned here.

RockMaterial caches shape copies and face bands at mesh construction. No new per-frame terrain pass. test_rock_material verifies continuous coverage, one upper rim, native source scale, shape isolation and tileset scope.

Desktop Gold validation: workspace/tests/mountain_texture_inspection_live.lua with EXPECT_ROCK_MATERIAL=1; six Route 45 views and Cherrygrove, zero mod errors. All 994 sampled cliff cell heights and native tile bindings match before/after. Screenshots: exports/media/mountain-materials-1.0.14 at workspace root. No physical mobile validation.
