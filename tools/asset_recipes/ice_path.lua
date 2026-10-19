-- Ice Path and the Hall of Fame share this atlas but no terrain artwork.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local function s(r,o,h,d,z) return {rect=r,orientation=o,height=h,depth=d,z=z or 0} end
local assets={}
local function add(a) assets[#assets+1]=a;return a end
local function put(a,x,y,z,i) a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=i,region=1} end
local function blank(id,tiles)
 return {id=id,tiles=tiles,surfaces={s({0,0,1,1},'vertical',0,1)},voxelEdits={{x=0,y=0,z=0,remove=true}}}
end
local rock=dofile(dir..'/cave.lua').tilesets.TILESET_CAVE.assets[1]
rock.id='ice_boulder';rock.tiles={{6,7},{22,23}};add(rock)

local up=add(blank('ice_ladder_up',{{10,11},{26,27}}))
for _,x in ipairs({5,10}) do for y=0,19 do for z=7,8 do put(up,x,y,z,(15-y%16)*16+5) end end end
for y=2,18,4 do for x=5,10 do put(up,x,y,7,8*16+7) end end

local function well(id,tiles,ladder)
 local a=add(blank(id,tiles));a.cutFloor=true
 -- A dark bottom and four walls below y=0 leave the opening unobstructed.
 local dark=ladder and 11*16+3 or 0
 for x=0,15 do for z=0,15 do put(a,x,-16,z,dark) end end
 for y=-15,-1 do for n=0,15 do
  put(a,0,y,n,dark);put(a,15,y,n,dark);put(a,n,y,0,dark);put(a,n,y,15,dark)
 end end
 if ladder then
  for _,x in ipairs({5,10}) do for y=-15,2 do put(a,x,y,3,math.max(0,math.min(15,-y))*16+8) end end
  for y=-14,2,4 do for x=5,10 do put(a,x,y,3,7*16+8) end end
  -- The rim uses the source's surrounding cave floor, not the black well.
  for n=0,15 do put(a,n,0,0,n);put(a,n,0,15,n);put(a,0,0,n,0);put(a,15,0,n,15) end
 end
 return a
end
well('ice_ladder_down',{{42,43},{58,59}},true)
well('ice_pit',{{16,16},{16,16}},false)

local exit=add({id='ice_exit',tiles={{66,67},{18,18}},surfaces={s({0,0,16,8},'horizontal',0,1)},voxelEdits={}})
for x=0,15 do for z=0,15 do
 for y=13,15 do put(exit,x,y,z,(8+z%8)*16+x) end
 if x<2 or x>13 then for y=0,12 do put(exit,x,y,z,(8+y%8)*16+x) end end
end end

local hall=add(blank('ice_hall_machine',{
 {40,83,44,45,45,46,83,41},{62,56,73,14,15,74,57,63},
 {40,84,72,30,31,75,86,41},{62,84,88,89,90,91,85,63},
 {76,77,56,47,47,57,78,79},{92,93,87,71,71,71,94,95}}))
-- The long side stripes are a horizontal platform border, not upright wings.
-- Preserve the landing pixel-for-pixel, hiding the console drawing underneath
-- its casing rather than repeating one scanline across the whole platform.
for x=0,63 do for z=0,39 do
 local sourceZ=(x>=16 and x<=47 and z<32) and 33 or z
 put(hall,x,7,z,sourceZ*64+x)
end end
for y=0,6 do for x=0,63 do put(hall,x,y,0,40*64+x);put(hall,x,y,39,40*64+x) end
 for z=0,39 do put(hall,0,y,z,z*64+2);put(hall,63,y,z,z*64+61) end
end
-- The upper twelve sprite rows describe the lid; the remaining twenty
-- describe the front screen and controls. Both meet on a compact casing.
hall.surfaces[#hall.surfaces+1]=s({16,0,32,12},'horizontal',28,1)
hall.surfaces[#hall.surfaces+1]=s({16,12,32,20},'vertical',8,12)
-- Four 2px steps: south is room floor, north meets the 8px landing.
for step=0,3 do
 local z0=40+step*2;local top=7-step*2
 for x=16,47 do for z=z0,z0+1 do for y=0,top do put(hall,x,y,z,(40+step*2)*64+x) end end end
end
add({id='ice_hall_terminal',tiles={{38,39},{54,55},{69,70}},surfaces={
 s({0,0,16,4},'horizontal',20,1),s({0,4,16,20},'vertical',0,10)}})

return {tilesets={TILESET_ICE_PATH={
 terrain_edges=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/low_cave_edges.lua').tilesets.TILESET_ICE_PATH.terrain_edges,
 classes={ice_wall={base='wall',height=16,art='flat'},ice_plateau={base='wall',height=16,art='flat'},ice_hall_wall={base='wall',height=16,art='flat'}},
 pins={
  ground={8,24,25,12,13,28,29}, -- sliding ice, cave floor and Hall of Fame carpet stay flat
  ice_wall={1,2,3,17,19,33,34,35,36,37}, -- complete rocky perimeter, all at one height
  ice_plateau={18}, -- walkable plateau inside that perimeter
  stair_n={60,61}, -- two-row flights rise north from the ice onto the plateau
  ice_hall_wall={82,83}, -- continuous rear mechanical wall
  void={16}, -- the open puzzle pits replace these dark tiles
 },assets=assets,planter_spray=false,
}}}
