-- Gatehouses, Goldenrod's vendors, and the three link rooms share this art.
local function s(r,o,h,d,z) return {rect=r,orientation=o,height=h,depth=d,z=z or 0} end
local assets={}
local function add(a) assets[#assets+1]=a;return a end
local function put(a,x,y,z,i) a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=i,region=1} end
local function blank(id,tiles)
 return {id=id,tiles=tiles,surfaces={s({0,0,1,1},'vertical',0,1)},voxelEdits={{x=0,y=0,z=0,remove=true}}}
end
-- Full wall panels retain their light strip on the upright face.
add({id='gate_wall_panel',tiles={{92,93},{16,16}},surfaces={s({0,0,16,16},'vertical',0,8)}})
add({id='gate_north_door',tiles={{2,3},{18,19}},surfaces={s({0,0,16,16},'vertical',0,4,4)}})
add({id='gate_wall_sign',tiles={{23,53},{16,16}},surfaces={s({0,0,16,16},'vertical',0,8)}})
local terminal=add({id='gate_park_terminal',tiles={{72,73},{74,75},{78,79}},surfaces={
 s({0,0,16,16},'vertical',8,8),s({0,16,16,8},'horizontal',8,2,8)},voxelEdits={}})
for x=2,13 do for z=2,13 do for y=0,7 do put(terminal,x,y,z,14*16+8) end end end

-- Match the entire freestanding vendor desk before the generic counter pins.
local desk=add({id='gate_vendor_table',tiles={{8,9},{24,25},{24,25},{24,25},{24,25},{36,37}},
 surfaces={s({0,0,16,40},'horizontal',9,2)},voxelEdits={}})
for _,x0 in ipairs({1,12}) do for _,z0 in ipairs({1,36}) do
 for x=x0,x0+2 do for z=z0,z0+2 do for y=0,8 do put(desk,x,y,z,44*16+x) end end end
end end
for _,variant in ipairs({{'front',7,7},{'left',8,7},{'right',7,9},{'end',24,25}}) do
 add({id='gate_counter_'..variant[1],tiles={{variant[2],variant[3]},{36,37}},surfaces={
  s({0,0,16,8},'horizontal',8,2),s({0,8,16,8},'vertical',0,8)}})
end
local chair=add({id='gate_chair',tiles={{84,85},{86,87}},surfaces={
 s({2,0,12,7},'vertical',6,2),s({2,7,12,6},'horizontal',4,2,2)},voxelEdits={}})
for _,x in ipairs({3,12}) do for _,z in ipairs({3,6}) do for y=0,3 do put(chair,x,y,z,14*16+x) end end end

local function planter(id,long)
 local tiles=long and {{56,57},{5,6},{5,6},{21,22}} or {{56,57},{21,22}}
 local H,D=#tiles*8,long and 24 or 12
 local a=add({id=id,tiles=tiles,surfaces={s({1,H-8,14,8},'vertical',0,D)},voxelEdits={}})
 -- A rounded, connected crown above the planter, using only its leaf pixels.
 for x=0,15 do for z=0,D-1 do for y=8,20 do
  if ((x-7.5)/8)^2+((z-(D-1)/2)/(D/2))^2+((y-11)/10)^2<=1 then
   local above=((x-7.5)/8)^2+((z-(D-1)/2)/(D/2))^2+((y+1-11)/10)^2
   local sy=above>1 and math.floor(z*(H-8)/D) or math.floor((20-y)*(H-8)/13)
   sy=math.max(1,math.min(H-10,sy))
   -- The source's outer columns outline a flat sprite; sample foliage
   -- inside that outline so the new side faces do not become black slabs.
   put(a,x,y,z,sy*16+math.max(3,math.min(12,x)))
  end
 end end end
 return a
end
planter('gate_long_planter',true);planter('gate_planter',false)

local register=add({id='gate_register',tiles={{14,15},{32,33}},
 surfaces={s({0,0,16,16},'horizontal',0,10)},voxelEdits={}})
-- Preserve the counter below the raised register; moving source pixels out
-- of a surface would otherwise leave holes in its supporting worktop.
for x=0,15 do for z=0,15 do put(register,x,9,z,14*16+8) end end
for x=1,14 do for z=1,8 do for y=10,17 do put(register,x,y,z,(17-y)*16+x) end end end

local stool=add(blank('gate_link_stool',{{64,65},{62,63}}))
for x=1,14 do for z=0,11 do
 local r=((x-7.5)/7)^2+((z-5.5)/6)^2
 if r<=1 then for y=6,8 do put(stool,x,y,z,math.min(7,z)*16+x) end end
 if r<=.22 then for y=0,5 do put(stool,x,y,z,12*16+x) end end
end end
local trade=add({id='gate_trade_console',tiles={{48,49,50,51},{36,37,36,37}},
 surfaces={s({0,0,32,8},'horizontal',9,2),s({0,8,32,8},'vertical',0,8)},voxelEdits={}})
-- Two raised terminals, joined by the low center console.
for _,x0 in ipairs({1,21}) do for x=x0,x0+9 do for z=0,4 do for y=11,15 do
 put(trade,x,y,z,math.max(0,15-y)*32+x)
end end end end
local battle=add(blank('gate_battle_console',{{52,46,47,52},{42,43,44,45},{58,59,60,61}}))
-- Paired sloping control wings around the tall central link housing.
for x=0,31 do for z=0,9 do
 local h=math.floor(10+13*math.max(0,1-math.abs(x-15.5)/8))
 for y=0,h do put(battle,x,y,z,(23-y)*32+x) end
end end

return {tilesets={TILESET_GATE={
 classes={gate_wall={base='wall',height=16,art='flat'},gate_counter={base='wall',height=10,art='flat'}},
 pins={
  ground={1,4,17,20,38,39,40,41,52,54,55,66,67,68,69,70,71}, -- floor, rugs, floor shadows and link-room insignia/platform
  gate_wall={2,3,16,18,19,23,53,92,93}, -- continuous lit north walls, doors and wall signs
  gate_counter={7,8,9,14,15,24,25,32,33,36,37}, -- gate service partitions; register/table assets own their complete patterns
  stair_w={80,81,82,83}, -- side drawing rises from east to west
  stair_down_e={88,89,90,91}, -- matching stairwell descends east, below the floor
  void={0}, -- unused space around the underground corridors and Victory Road gate
 },
 prop_ground={[56]=1,[57]=1,[5]=1,[6]=1,[21]=1,[22]=1,[84]=1,[85]=1,[86]=1,[87]=1,
  [64]=52,[65]=52,[62]=52,[63]=52,[48]=52,[49]=52,[50]=52,[51]=52,
  [42]=52,[43]=52,[44]=52,[45]=52,[46]=52,[47]=52,[58]=52,[59]=52,[60]=52,[61]=52},
 assets=assets,planter_spray=false,
}}}
