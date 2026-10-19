-- Celadon Mansion offices, lobby and roof. Complete source patterns prevent
-- monitor artwork and desk shadows becoming separate floor-height blocks.
local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local P=dofile(root..'/historic_primitives.lua');local s=P.s;local assets={}
local function add(a) assets[#assets+1]=a;return a end
local desk=add(P.blank('mansion_workdesk',{{42,43,44,45},{58,59,60,61},{74,75,76,77},{90,91,17,17}}))
-- Desk spans both the keyboard and monitor with space underneath.
P.box(desk,0,8,0,32,2,15,function(x,y,z)return 10*32+x end)
for _,x in ipairs({1,28}) do for _,z in ipairs({1,12}) do P.box(desk,x,0,z,3,8,3,14*32+x) end end
P.box(desk,18,10,1,12,11,8,function(x,y,z)return math.min(7,20-y)*32+x end)
P.box(desk,2,10,4,12,1,6,function(x,y,z)return (z+2)*32+x end)
-- Chair is included in the same pattern but remains a separate supported seat.
P.box(desk,2,4,19,11,2,9,function(x,y,z)return (z-3)*32+x end)
P.box(desk,2,6,26,11,7,2,function(x,y,z)return (31-y)*32+x end)
for _,x in ipairs({3,10}) do for _,z in ipairs({20,25}) do P.box(desk,x,0,z,2,4,2,30*32+x) end end
add(P.cabinet('mansion_bookshelf',{{54,56},{34,35},{50,51}},4,10))
add(P.cabinet('mansion_bookshelf_open',{{54,56},{36,37},{52,53},{50,51}},4,10))
add(P.cabinet('mansion_filing_cabinet',{{6,7},{22,23},{22,23},{38,39}},4,10))
add(P.table('mansion_lobby_table',{{54,55,55,56},{70,71,71,72},{70,71,71,72},{86,87,87,88}}))
local plant=add(P.blank('mansion_potted_tree',{{46,47},{94,95}}))
for y=0,5 do for x=3,12 do for z=3,12 do if (x-7.5)^2+(z-7.5)^2<=(4+y*.3)^2 then P.put(plant,x,y,z,(15-y)*16+x) end end end end
P.box(plant,7,6,7,2,7,2,14*16+7)
P.ellipsoid(plant,7.5,18,7.5,7.5,10,7.5,function(x,y,z)return math.max(0,math.min(7,27-y))*16+x end)
add({id='mansion_elevator',tiles={{32,33},{48,49}},surfaces={s({0,0,16,16},'vertical',0,14)}})
-- The stair graphics show westward landings on the upper and lower floors.
-- Whole furniture patterns claim before their reusable component sprites.
for i,a in ipairs(assets) do a._order=i end
table.sort(assets,function(a,b) local aa,bb=#a.tiles*#a.tiles[1],#b.tiles*#b.tiles[1];return aa==bb and a._order<b._order or aa>bb end)
for _,a in ipairs(assets) do a._order=nil end
return {tilesets={TILESET_MANSION={assets=assets,planter_spray=false,
 classes={mansion_wall={base='wall',height=16,art='flat'},mansion_roof={base='wall',height=24,art='flat'}},
 pins={ground={0,1,4,17,40}, -- lobby floor, office carpet and exit rugs
 mansion_wall={3,5,12,14,15,18,19,20,21,28,30,31,41,57,68,69,73,84,85,89}, -- partitions and parapet stay level
 mansion_roof={54,55,56,70,71,72,86,87,88,92,93}, -- roof hut uses a single plain elevated course
 stair_w={10,11,26,27},stair_down_w={8,9,24,25},
 },prop_ground={[46]=17,[47]=17,[94]=17,[95]=17},
}}}
