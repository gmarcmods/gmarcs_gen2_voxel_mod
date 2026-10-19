-- Warehouse, port passages, Underground Path, Saffron Gym and Rocket B1F.
local function s(r,o,h,d,z) return {rect=r,orientation=o,height=h,depth=d,z=z or 0} end
local assets={};local function add(a) assets[#assets+1]=a;return a end
local function put(a,x,y,z,i) a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=i,region=1} end
add({id='underground_crate',tiles={{67,68},{83,84}},surfaces={s({0,0,16,8},'horizontal',12,2),s({0,8,16,8},'vertical',4,8)},voxelEdits={}})
-- Complete crate body down to the floor; top remains a visibly raised lid.
local crate=assets[1];for x=0,15 do for z=0,7 do for y=0,3 do put(crate,x,y,z,14*16+x) end end end
for _,variant in ipairs({{'statue',69,70,85,86},{'gym_statue',7,8,23,24}}) do
 local a=add({id='underground_'..variant[1],tiles={{variant[2],variant[3]},{variant[4],variant[5]},{9,25},{48,49}},surfaces={s({2,16,12,16},'vertical',0,12,2)},voxelEdits={}})
 for x=0,15 do for z=0,15 do for y=16,32 do
  if ((x-7.5)/7)^2+((z-7.5)/6)^2+((y-24)/9)^2<=1 then put(a,x,y,z,math.max(0,31-y)*16+x) end
 end end end
 for x=1,14 do for z=1,14 do for y=0,2 do put(a,x,y,z,30*16+x) end end end
end
local plant=add({id='underground_plant',tiles={{30,31},{46,47},{62,63}},surfaces={s({6,16,4,8},'vertical',0,4,6)},voxelEdits={}})
for x=0,15 do for z=0,15 do for y=7,25 do
 if ((x-7.5)/8)^2+((z-7.5)/7)^2+((y-16)/10)^2<=1 then put(plant,x,y,z,math.max(1,math.min(14,24-y))*16+math.max(2,math.min(13,x))) end
end end end
add({id='underground_bookcase',tiles={{64,66},{26,27},{26,27},{28,29}},surfaces={s({0,0,16,32},'vertical',0,8)}})
local desk=add({id='underground_computer_desk',tiles={{64,65,78,79},{80,93,94,95},{38,39,54,55}},surfaces={s({0,0,32,16},'horizontal',8,2),s({18,6,12,10},'vertical',10,6,2)},voxelEdits={}})
for _,x0 in ipairs({1,28}) do for _,z0 in ipairs({1,12}) do for x=x0,x0+2 do for z=z0,z0+2 do for y=0,7 do put(desk,x,y,z,20*32+x) end end end end end
-- A monitor pedestal touches the desk; moving its texels must not punch holes.
for x=18,29 do for z=2,9 do for y=8,9 do put(desk,x,y,z,4*32+8) end end end
add({id='underground_stool',tiles={{40,41},{56,57}},surfaces={s({2,0,12,8},'horizontal',6,2),s({3,8,2,8},'vertical',0,2),s({11,8,2,8},'vertical',0,2)}})
local ground={};for _,a in ipairs(assets) do for _,r in ipairs(a.tiles) do for _,t in ipairs(r) do ground[t]=16 end end end
local detail=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/detail_geometry.lua')
for _,a in ipairs(assets)do if a.id=='underground_gym_statue' then detail.southCell(a) end end
local persian=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/persian_statue.lua')
for _,a in ipairs(assets)do persian.repair(a)end
local mall=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/mall_furniture.lua')
for _,a in ipairs(assets)do mall.repair(a)end
local audited=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/statue_repairs.lua')
for _,a in ipairs(assets)do audited.repair(a)end
local rocket=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/rocket_furniture.lua')
rocket.apply({buildings={TILESET_UNDERGROUND=assets,TILESET_FACILITY={}}})
return {tilesets={TILESET_UNDERGROUND={assets=assets,prop_ground=ground,planter_spray=false,
 classes={underground_wall={base='wall',height=16,art='flat'}},pins={
 ground={16,52,2,18,34,35,50,51}, -- checker floor, warp pads and exit mats are walking surfaces
 underground_wall={3,4,5,12,13,19,20,21}, -- uniform height for blue wall bands and gray caps
 stair_e={42,43,58,59}, -- side stairs climb from west to east
 stair_down_w={44,45,60,61}, -- dark stairwell descends west from the east landing
 void={0,1}, -- dark space around the disconnected corridor rooms
 }}}}
