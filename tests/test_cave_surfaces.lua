local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/tests/')
local C=dofile(root..'/lib/CaveSurface.lua')
local source={class='cave_rim',base='wall',h=16,art='flat',flat=true,authored=true}
local map={tileset={id='TILESET_DARK_CAVE'}}
local shape=C.at(map,source)
assert(shape.sideTile==22 and shape.h==16 and shape.class=='cave_rim','cave sides must use solid native rock, preserving height/top class')
assert(source.sideTile==nil and C.at(map,source)==shape,'shared authored classes must remain unchanged and copies cached')
local ledge={class='ledge',h=2};assert(C.at(map,ledge)==ledge,'low jump faces changed')
map.tileset.id='TILESET_HOUSE';assert(C.at(map,source)==source,'indoor furniture changed')
print('Cave rock side material: solid native texels, original top/height, no authored mutation PASS')
-- Reused rim art must not rise above a native walkable bank or water cell.
map.tileset.id='TILESET_DARK_CAVE'
map.isWalkableCell=function(_,x,y)return x==1 and y==1 or x==4 and y==4 end
map.isWaterCell=function(_,x,y)return x==2 and y==1 end
local floor=C.at(map,source,2,2)
assert(floor.h==0 and floor.flat and floor.class=='ground','walkable cave bank became a wall')
local water=C.at(map,source,4,2)
assert(water.h==-2 and water.class=='water'and water.topTile==20,'water reused as rim art became solid rock')
assert(C.at(map,source,8,8).h==16,'unrelated raised platform away from water changed')
assert(C.at(map,source,0,0).h==16,'solid cave boundary lost its wall')
assert(source.h==16 and source.class=='cave_rim','cell correction mutated authored profile')
print('Native cave traversal: low banks, open water and real solid walls remain distinct PASS')

map.def={environment='INDOOR'};assert(C.at(map,source,2,2)==source,'non-cave room sharing a cave tileset changed')
map.def={environment='CAVE'}
map.cellCollision=function(_,x,y)return x==4 and y==4 and 0xb2 or 0 end
local rim=C.at(map,source,8,8)
assert(rim.class=='cave_rim'and rim.h==16,'north platform border was lowered as if it were a jump ledge')
print('Cave platform side-wall collision retains the same height as the rock fill PASS')
