-- Seven maps share the casino/cafe/gym atlas. Match complete objects so
-- casino machine sides do not turn shared counter tiles into tall walls.
local function s(r,o,h,d,z) return {rect=r,orientation=o,height=h,depth=d,z=z or 0} end
local assets={}
local function add(a) assets[#assets+1]=a;return a end
local function put(a,x,y,z,i) a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=i,region=1} end
local function blank(id,tiles) return {id=id,tiles=tiles,surfaces={s({0,0,1,1},'vertical',0,1)},voxelEdits={{x=0,y=0,z=0,remove=true}}} end
local bank=add(blank('game_machine_bank',{}))
for row=1,14 do bank.tiles[row]=(row%2==1) and {4,5,4,5} or {20,21,20,21} end
bank.tiles[12]={34,35,34,35};bank.tiles[13]={42,43,34,35};bank.tiles[14]={58,59,50,51}
-- Six cabinets on either side. A one-pixel seam separates adjacent bodies.
bank.surfaces[#bank.surfaces+1]=s({0,0,32,16},'horizontal',0,20)
for n=0,5 do
 local z0=16+n*16
 for _,x0 in ipairs({2,16}) do bank.surfaces[#bank.surfaces+1]=s({x0,z0,14,15},'horizontal',0,24,z0+1) end
 -- Reuse the front/end artwork within this selected 32x112 sprite, turning
 -- it toward the chairs. Only the visible faces require explicit voxels.
 for u=0,15 do for y=0,23 do
  put(bank,1,y,z0+u,(88+23-y)*32+(15-u))
  put(bank,30,y,z0+u,(88+23-y)*32+16+u)
 end end
end
-- The last body is drawn with its face in the original sprite; its roof
-- still uses the same blue casing texel as the other cabinets.
for x=2,29 do for z=97,111 do put(bank,x,23,z,8*32+8) end end
-- Preserve the original pair of front panels on the aisle end as well.
for x=0,31 do for y=0,23 do put(bank,x,y,111,(88+23-y)*32+x) end end
add({id='game_front_machine',tiles={{4,5},{34,35},{34,35},{50,51}},surfaces={s({0,0,16,8},'horizontal',24,1),s({0,8,16,24},'vertical',0,12)}})
add({id='game_prize_shelf',tiles={{22,23,23,24},{38,39,39,40},{54,55,55,56}},surfaces={s({0,0,32,8},'horizontal',16,1),s({0,8,32,16},'vertical',0,10)}})
add({id='game_wall_poster',tiles={{6,7},{8,9}},surfaces={s({0,0,16,16},'vertical',8,2)}})
add({id='game_register',tiles={{52,53},{64,65}},surfaces={s({3,3,12,5},'vertical',14,6,4),s({1,8,15,8},'horizontal',10,4,4)}})
local chair=add({id='game_chair',tiles={{10,11},{26,27}},surfaces={s({2,1,12,6},'vertical',6,2),s({2,7,12,5},'horizontal',4,2,2)},voxelEdits={}})
for _,x in ipairs({4,11}) do for _,z in ipairs({3,6}) do for y=0,3 do put(chair,x,y,z,14*16+x) end end end
local function cafeTable(id,decorated)
 local tiles=decorated and {{46,13,13,47},{28,32,33,29},{28,48,49,29},{62,80,80,63},{17,78,79,18}}
  or {{46,13,13,47},{28,12,12,29},{62,80,80,63},{17,78,79,18}}
 local a=add(blank(id,tiles));local D=decorated and 32 or 24
 for z=0,D-1 do
  local inset=math.max(0,7-math.min(z,D-1-z))
  a.surfaces[#a.surfaces+1]=s({inset,z,32-2*inset,1},'horizontal',9,2,z)
 end
 for x=13,18 do for z=10,D-10 do for y=0,8 do put(a,x,y,z,D*32+16) end end end
 for x=10,21 do for z=9,D-9 do put(a,x,0,z,D*32+16) end end
 if decorated then
  -- Small bowl above the top: open center, a solid bottom and rounded rim.
  for x=8,23 do for z=8,23 do
   local r=(x-15.5)^2+(z-15.5)^2
   if r<=56 then
    local top=r>30 and 16 or 12
    for y=11,top do put(a,x,y,z,(8+math.floor((z-8)/2))*32+x) end
   end
  end end
 end
 return a
end
cafeTable('game_cafe_table',false);cafeTable('game_cafe_bowl_table',true)
local tree=add(blank('game_potted_tree',{{25,44},{41,60},{57,15},{36,37}}))
for y=0,7 do for x=3,12 do for z=3,12 do put(tree,x,y,z,(31-y)*16+x) end end end
for y=8,17 do for x=7,9 do for z=7,9 do put(tree,x,y,z,19*16+x) end end end
for y=15,30 do for x=0,15 do for z=0,15 do
 if ((x-7.5)/8)^2+((y-22)/9)^2+((z-7.5)/8)^2<=1 then put(tree,x,y,z,math.max(2,math.min(14,30-y))*16+x) end
end end end
local bin=add(blank('game_gym_bin',{{70,71},{86,87}}))
for y=0,9 do for x=0,15 do for z=0,15 do
 local r=(x-7.5)^2+(z-7.5)^2
 if r<=56 and (y<3 or r>=30) then
  local sy=y>=7 and z or 8+math.min(7,9-y)
  put(bin,x,y,z,sy*16+x)
 end
end end end
local statue=add({id='game_gym_statue',tiles={{66,67},{82,83},{68,69},{84,85}},surfaces={s({2,16,12,16},'vertical',0,10,3)},voxelEdits={}})
for y=0,15 do for x=0,15 do for z=3,12 do
 if ((x-7.5)/8)^2+((y-7.5)/8)^2+((z-7.5)/6)^2<=1 then put(statue,x,y+16,z,(15-y)*16+x) end
end end end
local detail=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/detail_geometry.lua')
for _,a in ipairs(assets)do if a.id=='game_gym_statue' then detail.southCell(a) end end
local audited=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/statue_repairs.lua')
for _,a in ipairs(assets)do audited.repair(a)end
return {tilesets={TILESET_GAME_CORNER={
 classes={game_wall={base='wall',height=24,art='flat'},game_counter={base='wall',height=10,art='flat'},game_gym_wall={base='wall',height=24,art='flat'}},
 pins={ground={0,1,16,17,18,3,19}, -- patterned floors and entrance carpet
 game_wall={2}, -- continuous rear masonry
 game_counter={4,5,20,21,14,30,31,61,77}, -- casino/cafe counters; complete machines override their own footprint
 game_gym_wall={72,73,74,75,76,88,89,90,91,92,93,94,95}, -- Vermilion partitions and facing courses
 void={45}, -- space behind the gym partitions
 },when_below={[77]={{below={91},class='game_gym_wall'}}}, -- shared blue cap is taller only above the gym fascia
 assets=assets,planter_spray=false,
}}}
