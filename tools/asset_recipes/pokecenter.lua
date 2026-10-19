local p=debug.getinfo(1,'S').source:sub(2):match('(.+)/');local H=dofile(p..'/public_interior_shapes.lua');local s=H.s
local machine=H.blank('center_healing_machine',{{28,29,30,31},{44,45,46,47},{60,61,61,63},{76,77,78,79}})
-- Raised curved housing, with the six-ball tray ahead of its dark opening.
for x=0,31 do for z=0,13 do for y=0,29 do
 local inset=math.max(0,y-23);if x>=inset and x<32-inset and (x<5 or x>26 or y>22 or y<7 or z<3) then H.put(machine,x,y,z,(31-y)*32+x) end
end end end
for x=1,30 do for z=14,31 do for y=0,9 do H.put(machine,x,y,z,(24+math.floor((z-14)*8/18))*32+x) end end end
local computer={id='center_computer',tiles={{32,33},{48,49},{64,65}},surfaces={
 s({0,0,16,4},'horizontal',20,1),
 s({0,4,16,9},'vertical',11,8),
 s({0,13,16,5},'horizontal',10,1,8),
 s({0,18,16,6},'vertical',4,8)},voxelEdits={}}
-- Recess the CRT glass two pixels behind its frame; keep the keyboard
-- horizontal and carry the base on the two legs drawn in the source.
for x=3,12 do for y=14,18 do for z=6,7 do
 computer.voxelEdits[#computer.voxelEdits+1]={x=x,y=y,z=z,remove=true}
end end end
for _,x0 in ipairs({1,12})do for x=x0,x0+2 do for y=0,3 do for z=0,7 do
 H.put(computer,x,y,z,23*16+x)
end end end end
local assets={{id='center_counter_return',tiles={{15},{15}},surfaces={s({0,0,8,16},'horizontal',0,10)}},machine,computer,H.stool('center_seat',{{72,73},{88,89}}),
 H.box('center_storage_unit',{{4,5},{20,21},{10,11},{26,27}},8),
 {id='pokecenter_counter_edge',tiles={{3,37},{19,53},{70,71}},surfaces={s({0,0,16,16},'vertical',8,8),s({0,16,16,8},'vertical',0,8)}},
 {id='pokecenter_counter',tiles={{52,52},{36,36}},surfaces={s({0,0,16,8},'horizontal',8,2),s({0,8,16,8},'vertical',0,8)}},
 {id='pokecenter_ball_counter',tiles={{12,12},{36,36}},surfaces={s({0,0,16,8},'horizontal',8,2),s({0,8,16,8},'vertical',0,8)}},
}

assets[#assets+1]=H.box('center_indigo_stock',{{92,93},{94,95},{94,95},{42,43}},10)
assets[#assets+1]=H.box('center_link_trade_sign',{{8,9},{24,25}},4)
assets[#assets+1]=H.box('center_link_battle_sign',{{38,39},{40,41}},4)
assets[#assets+1]=H.box('center_wall_notice',{{34,35},{50,51}},4)
assets[#assets+1]={id='center_short_counter_edge',tiles={{3,37},{19,53},{36,36}},surfaces={s({0,0,16,16},'vertical',8,8),s({0,16,16,8},'vertical',0,8)}}
assets[#assets+1]={id='center_time_capsule',tiles={{6,54,31,92,55,7},{6,54,45,46,55,7},{58,62,62,62,62,59},{54,55,86,87,54,55},{54,55,34,35,54,55},{70,71,50,51,70,71}},surfaces={
 s({0,0,8,24},'vertical',0,24),s({40,0,8,24},'vertical',0,24),
 s({8,0,32,16},'vertical',8,5),s({8,16,32,8},'horizontal',0,2,5),
 s({16,24,16,24},'vertical',0,8,24)}}
-- The complete capsule must claim its embedded notice before generic signs.
table.insert(assets,1,table.remove(assets))
local repair=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/service_prop_repairs.lua')
for _,a in ipairs(assets)do repair(a)end
local station=dofile(p..'/center_station.lua')
for _,a in ipairs(assets)do station.repair(a)end
for _,a in ipairs(station.fillers())do assets[#assets+1]=a end
for _,a in ipairs(assets)do if a.id=='center_storage_unit'then a.groundTile=17 end end
return {tilesets={TILESET_POKECENTER={assets=assets,planter_spray=false,
 classes={pokecenter_wall={base='wall',height=16,art='flat'},pokecenter_counter={base='wall',height=7,art='flat'}},
 pins={ground={0,1,17,18,80,81},void={61},pokecenter_wall={2,22,23},pokecenter_counter={12,13,14,15,36,52,54,55,56,57,70,71},stair_w={68,69,84,85},stair_down_e={66,67,82,83}},
 prop_ground={[32]=17,[33]=17,[48]=17,[49]=17,[64]=17,[65]=17,[12]=17,[36]=17,[52]=17,[3]=17,[37]=17,[19]=17,[53]=17,[70]=17,[71]=17,[72]=17,[73]=17,[88]=17,[89]=17},
}}}
