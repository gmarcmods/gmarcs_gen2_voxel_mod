local root=arg[1]or'.'
local V={require=function(name)return dofile(root..'/lib/'..name..'.lua')end}
local Extensions=assert(loadfile(root..'/lib/ProfileExtensions.lua'))(V)
local function clone(v)if type(v)~='table'then return v end local r={}for k,x in pairs(v)do r[k]=clone(x)end return r end
local original={classes={native={base='wall',height=8}},tilesets={TILESET_HOUSE={wall={9}}},buildings={TILESET_HOUSE={{id='kept'}}}}
local calls=0
local registry=Extensions.new(original,{wall=16,ground=0},function()calls=calls+1 end)
local asset={id='table',tiles={{1}},surfaces={{rect={0,0,1,1},orientation='vertical',height=0,depth=1}},voxelEdits={{x=0,y=0,z=0,i=0}}}
local spec={schema='voxel.extension.v1',tilesetPrefix='HOENN_',classPrefix='hoenn_',classes={hoenn_table={base='wall',height=8}},tilesets={HOENN_A_TILES={hoenn_table={1}}},buildings={HOENN_A_TILES={asset}}}
assert(registry:register('addon',spec))
local profile=registry:current()
assert(profile.buildings.TILESET_HOUSE[1].id=='kept'and profile.classes.native.height==8)
assert(profile.buildings.TILESET_HOUSE==original.buildings.TILESET_HOUSE,'native branches must not be duplicated')
assert(profile.buildings.HOENN_A_TILES[1].voxelEdits[1].i==0)
assert(original.buildings.HOENN_A_TILES==nil and spec.buildings.HOENN_A_TILES[1].id=='table')
spec.buildings.HOENN_A_TILES[1].id='mutated';assert(profile.buildings.HOENN_A_TILES[1].id=='table')
assert(calls==1)
local bad=clone(spec);bad.tilesets.TILESET_HOUSE={};assert(not pcall(function()registry:register('bad',bad)end));assert(calls==1)
local conflict=clone(spec);assert(not pcall(function()registry:register('another',conflict)end))
local invalid=clone(spec);invalid.classes.hoenn_table.height=0/0;assert(not pcall(function()registry:register('addon',invalid)end))
assert(registry:current().classes.hoenn_table.height==8 and calls==1)
assert(registry:remove('addon'));assert(registry:current().buildings.HOENN_A_TILES==nil)
assert(registry:current().buildings.TILESET_HOUSE[1].id=='kept'and calls==2)
assert(not registry:remove('missing')and calls==2)
local configured=clone(spec)
configured.tilesets.HOENN_A_TILES.heights={hoenn_table=10}
configured.tilesets.HOENN_A_TILES.when_above={[1]={{above={2},class='hoenn_table'}}}
configured.tilesets.HOENN_A_TILES.terrain_edges={tiles={1},ledgeTiles={},capTiles={},shoreClass='hoenn_table',lipHeight=2,shoreHeight=1,topTile=0}
assert(registry:register('configured',configured))
assert(registry:current().tilesets.HOENN_A_TILES.heights.hoenn_table==10)
local invalidConfig=clone(configured);invalidConfig.tilesets.HOENN_A_TILES.terrain_edges.shoreClass='typo'
assert(not pcall(function()registry:register('configured',invalidConfig)end))
assert(registry:current().tilesets.HOENN_A_TILES.terrain_edges.shoreClass=='hoenn_table')
assert(registry:remove('configured'))
local loads=0
local lazy=Extensions.new(function()loads=loads+1;return original end,{wall=16,ground=0})
assert(loads==0 and #lazy:list()==0 and not lazy:remove('absent'),'unused API must not load the 39 MB profile')
assert(lazy:current().buildings.TILESET_HOUSE[1].id=='kept'and loads==1)
lazy:current();assert(loads==1,'base profile loaded twice')
local L=V.require('BorderTreeLOD')
assert(L.eligible({id='hoenn_tree',border=true,lodTree=true}))
assert(not L.eligible({id='desk',lodTree=true}))
assert(L.eligible({id='johto_tree',border=true}))
print('PROFILE EXTENSIONS PASS')
