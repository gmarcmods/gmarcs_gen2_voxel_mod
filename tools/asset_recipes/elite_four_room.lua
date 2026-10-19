-- Shared by four Elite Four rooms, six gym maps and the switch basement.
-- Every asset samples this tileset's own sprite pixels.
local function s(r,o,h,d,z) return {rect=r,orientation=o,height=h,depth=d,z=z or 0} end
local function voxel(a,x,y,z,i) a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=i,region=1} end
local orb={id='elite_orb_pedestal',tiles={{32,33},{48,49},{34,35},{50,51}},
 surfaces={s({2,16,12,16},'vertical',0,10,3)},voxelEdits={}}
for y=0,15 do for x=0,15 do for z=0,15 do
 if (x-7.5)^2+(y-7.5)^2+(z-7.5)^2<=64 then voxel(orb,x,y+16,z,math.max(2,math.min(13,15-y))*16+x) end
end end end
local function entrance(id,brick)
 local a={id=id,tiles={},surfaces={
  s({0,0,160,16},'vertical',16,2,14), -- wall and doors sit on the landing
  s({0,16,160,16},'horizontal',16,1,16),
 }}
 for row=1,8 do
  a.tiles[row]={}
  local side=({16,16,17,1,brick and 16 or 57,brick and 16 or 57,brick and 17 or 81,brick and 1 or 82})[row]
  for x=1,20 do a.tiles[row][x]=side end
 end
 for x=9,12 do a.tiles[1][x]=(x%2==1) and 72 or 73;a.tiles[2][x]=(x%2==1) and 74 or 75 end
 for row=5,8 do for x=9,12 do a.tiles[row][x]=({83,84,89,83})[x-8] end end
 for step=0,7 do a.surfaces[#a.surfaces+1]=s({64,32+step*4,32,4},'horizontal',0,16-step*2,32+step*4) end
 for _,x in ipairs({0,96}) do
  a.surfaces[#a.surfaces+1]=s({x,32,64,16},'vertical',0,2,32)
  a.surfaces[#a.surfaces+1]=s({x,48,64,16},'horizontal',0,1,48)
 end
 return a
end
local stairs=entrance('elite_north_stairs',false)
local brickStairs=entrance('elite_north_stairs_brick',true)
local tree={id='elite_indoor_tree',tiles={{11,12,13},{27,28,29},{46,47,10}},surfaces={s({0,0,1,1},'vertical',0,1)},voxelEdits={{x=0,y=0,z=0,remove=true}}}
for y=0,8 do for x=10,13 do for z=10,13 do voxel(tree,x,y,z,(23-y)*24+x) end end end
for y=8,25 do for x=1,22 do for z=1,21 do
 if ((x-11.5)/11)^2+((y-16.5)/9)^2+((z-11)/10)^2<=1 then
  local sy=math.max(2,math.min(14,25-y));voxel(tree,x,y,z,sy*24+x)
 end
end end end
local function planter(id,top)
 local a={id=id,tiles={top,{23,24}},surfaces={s({1,8,14,8},'vertical',0,12,2)},voxelEdits={}}
 for y=8,15 do for x=0,15 do for z=0,15 do
  if ((x-7.5)/8)^2+((y-9)/7)^2+((z-7.5)/8)^2<=1 then
   voxel(a,x,y,z,math.max(2,math.min(7,15-y))*16+x)
  end
 end end end
 return a
end
local bird={id='elite_bird_statue',tiles={{85,86},{87,88}},surfaces={s({0,0,1,1},'vertical',0,1)},voxelEdits={{x=0,y=0,z=0,remove=true}}}
for y=0,15 do for x=0,15 do for z=4,11 do
 local solid=(y<4 and x>=2 and x<=13) or (y>=4 and y<=11 and x>=5 and x<=10) or (y>=9 and ((x-7.5)/7)^2+((y-11)/5)^2<=1)
 if solid then voxel(bird,x,y,z,(15-y)*16+x) end
end end end
local ring={id='elite_dragon_emblem',tiles={{78,79},{94,95}},surfaces={s({0,0,1,1},'vertical',0,1)},voxelEdits={{x=0,y=0,z=0,remove=true}}}
for y=0,15 do for x=0,15 do for z=6,9 do
 local r=((x-7.5)/7.5)^2+((y-7.5)/8)^2
 if r<=1 and r>=.40 then voxel(ring,x,y,z,(15-y)*16+x) end
end end end
dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/detail_geometry.lua').southCell(orb)
local audited=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/statue_repairs.lua')
audited.repair(bird);audited.repair(ring)
return {tilesets={TILESET_ELITE_FOUR_ROOM={
 classes={
  elite_wall_cap={base='wall',height=32,art='flat'},
  elite_lava={base='water',height=-2,art='flat'},
  elite_void={base='void',height=-16,art='flat'},
  elite_ice_pool={base='water',height=-2,art='flat'},
 },
 pins={
  ground={1,3,4,5,6,15,17,18,19,20,21,22,30,31,36,40,57,80,81,82}, -- brick/carpet/grass/ice floors and edge art
  elite_lava={2,25,56,91}, -- animated lava stays below the bridges
  elite_void={0,9}, -- dark pits below Karen/Violet/Blackthorn walkways
  elite_ice_pool={14,90,92,93}, -- Will's reflective lower pools
  elite_wall_cap={37,38,39,53,54,55}, -- level masonry cap, no per-tile upright folding
  wall={16}, -- exposed masonry courses
  stair_e={44,45,60,61}, -- Blackthorn/basement stairs drawn west-to-east
  stair_down_e={64,65,66,67}, -- matching descending opening
 },planter_spray=false,
 assets={orb,stairs,brickStairs,tree,
  planter('elite_leaf_planter',{7,8}),planter('elite_flower_planter',{62,63}),bird,ring,
  {id='elite_square_block',tiles={{42,43},{58,59}},surfaces={s({0,0,16,16},'horizontal',0,12)}},
  {id='elite_basement_doors',tiles={{38,72,73,72,73,39},{54,74,75,74,75,55}},surfaces={s({0,0,48,16},'vertical',0,2,14)}},
  {id='elite_wall_switch',tiles={{76,77}},surfaces={s({0,0,16,8},'vertical',8,2,6)}},
 }
}}}
