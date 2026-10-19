-- Outdoor Johto only. Johto Modern has a different rock/tree atlas.
local function s(r,o,h,d,z) return {rect=r,orientation=o,height=h,depth=d,z=z or 0} end
local assets={}
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local function add(a) assets[#assets+1]=a;return a end
local function put(a,x,y,z,i) a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=i,region=1} end
local function blank(id,tiles)
 return add({id=id,tiles=tiles,surfaces={s({0,0,1,1},'vertical',0,1)},voxelEdits={{x=0,y=0,z=0,remove=true}}})
end
local function tree(id,tiles)
 local a=blank(id,tiles);a.border=true
 return dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/native_tree_shape.lua')(a)
end
-- Tall pattern precedes the small pattern sharing its crown and base tiles.
tree('johto_tree',{{30,31},{46,47},{46,47},{62,63}})
tree('johto_small_tree',{{30,31},{62,63}})
local cut=blank('johto_fruit_tree',{{19,21},{69,29}});cut.border=true
dofile(dir..'/detail_geometry.lua').cutTree(cut)
add({id='johto_sign',tiles={{78,79},{94,95}},surfaces={
 s({1,1,14,10},'vertical',5,2,7),s({1,11,2,5},'vertical',0,2,7),s({13,11,2,5},'vertical',0,2,7)}})
-- Single-column modules cover odd-length runs and don't leave a final wall
-- tile behind when a two-column match overlaps its neighbour.
local function rail(id,bottom,corner)
 local a=blank(id,{{90},{bottom}})
 for x=0,7 do for y=8,10 do for z=7,8 do put(a,x,y,z,8*8+x) end end end
 for x=1,3 do for y=0,12 do for z=7,8 do put(a,x,y,z,(15-math.min(15,y))*8+x) end end end
 if corner then for z=0,6 do for y=8,10 do for x=1,3 do put(a,x,y,z,8*8+1) end end end end
 return a
end
rail('johto_rail',89,false)
rail('johto_rail_corner',74,true)
local cave=blank('johto_cave_mouth',{{70,71},{86,87}})
-- Its dark drawing is the passage, not a black cube. Rock frames the opening.
for x=0,15 do for z=0,15 do
 for y=13,15 do put(cave,x,y,z,((x+z)%3)+((x*3+z)%2)*16) end
 if x<3 or x>12 then for y=0,12 do put(cave,x,y,z,(15-y)*16+(x<3 and 0 or 15)) end end
end end
-- Keep the threshold dark and flush with the approach.
cave.surfaces[#cave.surfaces+1]=s({3,8,10,8},'horizontal',0,1,4)
-- Olivine's 28-row sprite encodes six floors vertically, not a deep roof.
local towerTiles={
 {49,54,54,54,54,54,54,52},{65,72,72,72,72,72,72,68},
 {65,72,72,72,72,72,72,68},{81,82,82,82,82,82,82,84},
}
for row=5,27 do towerTiles[row]={26,7,7,7,7,7,7,28} end
for col=2,7 do towerTiles[6][col]=38 end
for _,row in ipairs({10,14,18,22}) do for _,col in ipairs({2,3,6,7}) do towerTiles[row][col]=38 end end
towerTiles[26][6]=38;towerTiles[26][7]=38;towerTiles[27][3]=55;towerTiles[27][4]=56
towerTiles[28]={1,2,57,58,2,2,2,22}
local tower=blank('johto_lighthouse',towerTiles)
-- Only the exterior shell is needed; keep the door beside its original warp.
for y=0,191 do
 local sy=223-y
 for x=0,63 do
  put(tower,x,y,(x>=18 and x<30 and y<14) and 220 or 223,sy*64+x)
  put(tower,x,y,192,(y<16 and 32 or sy)*64+x)
 end
 for z=193,222 do
  local sx=8+(z-192)%8
  put(tower,0,y,z,sy*64+sx);put(tower,63,y,z,sy*64+sx)
 end
end
for z=220,222 do
 for y=0,13 do put(tower,17,y,z,(223-y)*64+17);put(tower,30,y,z,(223-y)*64+30) end
 for x=18,29 do put(tower,x,14,z,209*64+x) end
end
dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.')..'/johto_windows.lua')(tower,223)
-- A shallow roof deck and parapet, mapped from the original top-facing band.
for x=0,63 do for z=192,223 do
 local source=(z-192)*64+x
 put(tower,x,192,z,source)
 if x<3 or x>60 or z<195 or z>220 then
  put(tower,x,193,z,source);put(tower,x,194,z,source)
 end
end end
local ground={}
for _,a in ipairs(assets) do if a~=tower then for _,row in ipairs(a.tiles) do for _,id in ipairs(row) do ground[id]=5 end end end end
for _,id in ipairs({78,79,94,95,90,89,70,71,86,87}) do ground[id]=6 end
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local architecture=dofile(dir..'/johto_architecture.lua')
for i=#architecture,1,-1 do table.insert(assets,1,architecture[i]) end
local entrance=dofile(dir..'/tunnel_entrances.lua')
for _,a in ipairs(assets)do entrance(a)end
assets[#assets+1]=dofile(dir..'/small_water_rock.lua')('johto_water_rock')
ground[88]=20 -- sea rocks stand in recessed animated water
local coast=dofile(dir..'/coastal_formations.lua').batch().tilesets.TILESET_JOHTO.assets
for i=#coast,1,-1 do table.insert(assets,1,coast[i])end
return {tilesets={TILESET_JOHTO={
 heights={ledge=3}, -- shallow jump lip; not a full tile-height wall
 classes={johto_cliff={base='wall',height=16,art='flat'},johto_plateau={base='wall',height=16,art='flat'},
  johto_shore={base='ledge',height=4,art='flat'}},
 pins={
  ground={0,5,6,72}, -- grass backing, path and bare earth stay at walking height
  grass={4}, -- encounter grass keeps the existing tuft primitive
  flower={3}, -- flowers remain individual blossoms
  water={20,73,88}, -- fill, north shore ripple and claimed sea-rock backing
  johto_plateau={54}, -- rock terrace interior meets its perimeter
  johto_cliff={43,44,45,59,60,61,75,77}, -- complete rock courses, consistent height
  ledge={76}, -- low hop-down course; cliffs and shore are context-dependent below
  post={74}, -- north/south rail posts stand thin rather than as a solid wall
  johto_shore={92,93}, -- inside water corners stay low
 },
 when_above={[76]={{above={44,54,59,60,61,75,76,77},class='johto_cliff'}}},
 when_below={
  [30]={},[31]={}, -- complete assets supersede the old per-tile tree shapes
  [76]={{below={20,73,88},class='johto_shore'}},
  [75]={{below={20,73,88},class='johto_shore'}},
  [77]={{below={20,73,88},class='johto_shore'}},
 },mountain={classes={"johto_cliff","johto_plateau"},rise=2,maxHeight=48,sideTile=54},
 prop_ground=ground,planter_spray=false,assets=assets,
}}}
