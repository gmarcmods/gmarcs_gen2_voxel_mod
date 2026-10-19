local p=debug.getinfo(1,'S').source:sub(2):match('(.+)/');local H=dofile(p..'/public_interior_shapes.lua');local s=H.s
local assets={
 H.box('mart_display',{{64,65,66,43},{80,81,82,69},{67,68,92,93},{83,84,31,85}},12),
 H.box('mart_shelf',{{12,13},{80,81},{80,81},{94,95}},12),
 H.box('mart_glass_cabinet',{{12,13},{86,87},{88,89},{90,91}},7),
 H.box('mart_blue_rack',{{38,39},{54,55},{40,41},{56,57}},10),
 {id='mart_register',tiles={{32,33},{48,49}},surfaces={s({0,0,16,12},'vertical',10,8),s({0,12,16,4},'horizontal',8,2,8)},voxelEdits={}},
 {id='mart_counter',tiles={{62,63}},surfaces={s({0,0,16,8},'horizontal',0,10)}},
 {id='mart_counter_end',tiles={{30,47},{26,25}},surfaces={s({0,0,16,8},'horizontal',8,2),s({0,8,16,8},'vertical',0,8)}},
}
-- The cash register stands on the same worktop as the adjacent service lane.
for x=0,15 do for z=0,11 do for y=0,9 do H.put(assets[5],x,y,z,14*16+8) end end end

assets[#assets+1]=H.box('mart_vending_machine',{{12,13},{76,77},{76,77},{78,79}},10)
assets[#assets+1]={id='mart_dept_window',tiles={{14,15},{28,29}},surfaces={s({0,0,16,16},'vertical',0,8)}}
assets[#assets+1]=H.box('mart_elevator_door',{{6,7},{22,23}},4)
assets[#assets+1]=H.box('mart_directory',{{44,45},{60,61}},6)
assets[#assets+1]=H.stool('mart_north_seat',{{34,35},{50,51}})
assets[#assets+1]=H.stool('mart_south_seat',{{36,37},{52,53}})
-- The long decorative hedge is a continuous raised planter, not flooring.
assets[#assets+1]={id='mart_hedge',tiles={{8,9}},surfaces={s({1,0,14,8},'horizontal',5,8)}}
assets[#assets+1]={id='mart_hedge_cap',tiles={{74,75}},surfaces={s({1,0,14,8},'horizontal',5,8)}}
local repair=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/service_prop_repairs.lua')
for _,a in ipairs(assets)do repair(a)end
local mall=dofile(p..'/mall_furniture.lua')
for _,a in ipairs(assets)do mall.repair(a)end
local extras=mall.extras();for i=#extras,1,-1 do table.insert(assets,1,extras[i])end
for _,a in ipairs(mall.fallbacks())do assets[#assets+1]=a end
local ground={}for _,a in ipairs(assets)do for _,row in ipairs(a.tiles)do for _,t in ipairs(row)do ground[t]=1 end end end
return {tilesets={TILESET_MART={assets=assets,planter_spray=false,
 classes={mart_wall={base='wall',height=24,art='flat'},mart_counter={base='wall',height=7,art='flat'}},
 pins={ground={0,1,11,27,58,70,71,72},mart_wall={10,12,13,14,15,17,73},mart_counter={24,25,26,30,42,43,46,47,59,62,63},stair_w={4,5,20,21},stair_down_e={2,3,18,19}},
 prop_ground=ground,
}}}
