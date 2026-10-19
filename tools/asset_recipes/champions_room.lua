-- Three maps share this atlas: Lance, Olivine Gym and the bike shop.
local function s(r,o,h,d,z) return {rect=r,orientation=o,height=h,depth=d,z=z or 0} end
local orb={id='champion_orb_pedestal',tiles={{46,47},{62,63},{78,79},{94,95}},
 surfaces={s({2,16,12,16},'vertical',0,10,3)},voxelEdits={}}
-- The orb is a sphere on a plinth, not three independently detected props.
for y=0,15 do for x=0,15 do for z=0,15 do
 if (x-7.5)^2+(y-7.5)^2+(z-7.5)^2<=64 then
  orb.voxelEdits[#orb.voxelEdits+1]={x=x,y=16+y,z=z,i=(15-y)*16+x,region=1}
 end
end end end
local batch={tilesets={TILESET_CHAMPIONS_ROOM={
 classes={champion_dais={base='wall',height=16,art='flat'},champion_rail={base='wall',height=16,art='flat'}},
 pins={
  ground={17,32,45,59,60,61,77,83,93}, -- shop floor, gym aisle and carpet
  champion_dais={74,90,64,66,67,68,69,72,80,81,82}, -- both raised arenas
  champion_rail={37,38,39,53,23,88,89}, -- continuous stone rail/cap
  stair_n={84,85}, -- repeated two-row stairs rising toward each arena
  wall={73}, -- back masonry
  bike={5,6,21,22,12,13,14,15,28,29,30,31,40,41,56,57,42}, -- thin frames/wheels, with floor removed by existing mask
 },assets={orb,
  {id='champion_exit_doors',tiles={{75,76,75,76},{91,92,91,92}},surfaces={s({0,0,32,16},'vertical',16,2,14)}},
  {id='bike_shop_shelf',tiles={{37,38,38,39},{54,55,55,58},{34,35,35,36},{50,51,51,52}},
   surfaces={s({0,0,32,8},'horizontal',24,1),s({0,8,32,24},'vertical',0,8)}},
  {id='bike_shop_counter',tiles={{37,39},{8,9},{24,25},{53,23},{53,23},{53,23},{53,23},{53,23},{48,49}},
   surfaces={s({0,0,16,8},'horizontal',0,9),s({0,8,16,16},'vertical',9,6,8),
    s({0,24,16,40},'horizontal',0,9,16),s({0,64,16,8},'horizontal',0,9,8)}},
  {id='bike_shop_wall_poster',tiles={{2,3},{43,44}},surfaces={s({0,0,16,16},'vertical',0,2)}},
  {id='bike_shop_wall_poster_right',tiles={{18,19},{43,44}},surfaces={s({0,0,16,16},'vertical',0,2)}},
  {id='bike_shop_wall_poster_plain',tiles={{18,19},{33,33}},surfaces={s({0,0,16,16},'vertical',0,2)}},
  {id='bike_shop_wall_plain',tiles={{1},{33}},surfaces={s({0,0,8,16},'vertical',0,2)}},
  {id='bike_shop_counter_return',tiles={{38,38},{7,7}},surfaces={s({0,0,16,16},'horizontal',0,9)}},
 }}}}
local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
for _,a in ipairs(dofile(root..'/champion_bikes.lua')) do
 batch.tilesets.TILESET_CHAMPIONS_ROOM.assets[#batch.tilesets.TILESET_CHAMPIONS_ROOM.assets+1]=a
end
dofile(root..'/champion_statue_repair.lua').asset(orb)
return batch
