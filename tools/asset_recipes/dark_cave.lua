-- Dark Cave has the same terrain arrangements, with darker source shading.
-- Reuse the authored geometry, sampling this atlas's own texels at runtime.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local base=dofile(dir..'/cave.lua').tilesets.TILESET_CAVE
local rim=dofile(dir..'/cave_stairs_walls.lua').tilesets.TILESET_CAVE
base.classes.cave_rim=rim.classes.cave_rim
base.pins.wall=nil;base.pins.cave_rim=rim.pins.cave_rim;base.pins.stair_n=rim.pins.stair_n
base.assets[1].id='dark_cave_boulder'
return {tilesets={TILESET_DARK_CAVE=base}}
