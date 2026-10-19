local p=debug.getinfo(1,'S').source:sub(2):match('(.+)/');local H=dofile(p..'/public_interior_shapes.lua');local s=H.s
local train=H.blank('station_train',{{31,5,6,10,10,10,9,10,10,10,10,10,10,9,10,10,10,11,12,31},{20,21,22,26,26,26,25,26,26,26,26,26,26,25,26,26,26,27,28,29},{36,37,38,39,7,47,41,39,40,40,40,40,42,41,7,47,42,43,44,45},{32,31,46,31,23,0,46,31,31,31,31,31,31,46,23,0,31,46,31,15}})
-- Horizontal train axis follows the actual platform. The white nose tapers
-- in both height and depth; the orange stripe stays on the side face.
for x=0,159 do
 local endDistance=math.min(x,159-x);local inset=math.max(0,12-math.floor(endDistance*.7))
 local top=math.min(28,10+math.floor(endDistance*.8))
 for z=inset,31-inset do for y=4,top do
  local edge=x<2 or x>157 or z==inset or z==31-inset or y==4 or y==top
  if edge then local sy=math.max(0,math.min(31,31-y));if y==top then sy=math.min(7,math.floor(z/4)) end;H.put(train,x,y,z,sy*160+x) end
 end end
end
-- Two bogies support the shell, with the source's dark wheel pixels.
for _,x0 in ipairs({29,109}) do for x=x0,x0+18 do for z=4,27 do for y=0,3 do H.put(train,x,y,z,31*160+x) end end end end
local gate={id='station_turnstile',tiles={{53,54},{55,56},{57,58},{59,60}},surfaces={s({0,0,16,24},'horizontal',12,2),s({0,24,16,8},'vertical',4,24)},voxelEdits={}}
local assets={train,gate,H.stool('station_seat',{{64,65},{66,67}}),
 H.plant('station_planter',{{80,81},{82,83},{82,83},{84,85}}),
 H.blank('station_railing',{{8},{24}}),
}
local rail=assets[5]
for x=0,7 do for z=6,7 do for y=0,12 do if x==3 or x==4 or y==10 or y==11 then H.put(rail,x,y,z,(15-y)*8+x) end end end end

assets[#assets+1]=H.plant('station_short_planter',{{80,81},{84,85}})
assets[#assets+1]=H.plant('station_medium_planter',{{80,81},{82,83},{84,85}})
assets[#assets+1]=H.plant('station_gym_shrub',{{76,77},{92,93}})
assets[#assets+1]={id='station_dojo_scroll',tiles={{78,79},{94,95}},surfaces={s({0,0,16,16},'vertical',8,4)}}
local function statue(id,t)
 local a=H.blank(id,t)
 for x=1,14 do for z=1,12 do for y=0,17 do H.put(a,x,y,z,(31-y)*16+x) end end end
 for x=2,13 do for z=3,12 do for y=18,29 do
 if ((x-7.5)/6)^2+((z-7.5)/5)^2+((y-23)/7)^2<=1 then H.put(a,x,y,z,math.max(0,29-y)*16+x) end
 end end end
 return a
end
assets[#assets+1]=statue('station_gym_statue',{{72,73},{88,89},{74,75},{90,91}})
assets[#assets+1]=statue('station_dojo_statue',{{72,73},{88,89},{16,1},{90,91}})
assets[#assets+1]={id='station_gym_foliage',tiles={{2,3},{18,19}},surfaces={s({1,0,14,12},'vertical',0,12)}}
assets[#assets+1]={id='station_gym_foliage_top',tiles={{2,3}},surfaces={s({1,0,14,8},'horizontal',2,8)}}
assets[#assets+1]={id='station_gym_foliage_base',tiles={{18,19}},surfaces={s({1,0,14,8},'horizontal',0,4)}}
local detail=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/detail_geometry.lua')
for _,a in ipairs(assets)do if a.id=='station_gym_statue' then detail.southCell(a) end end
local audited=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/statue_repairs.lua')
for _,a in ipairs(assets)do audited.repair(a)end
return {tilesets={TILESET_TRAIN_STATION={assets=assets,planter_spray=false,
 classes={station_shrub={base='wall',height=8,art='flat'},station_wall={base='wall',height=32,art='flat'}},
 pins={ground={14,30,31,17,50,51,61,62,68,69,70,71,33,86,87},station_shrub={2,3},station_wall={48,55,56},void={49}},
 prop_ground={[64]=61,[65]=61,[66]=61,[67]=61,[80]=61,[81]=61,[82]=61,[83]=61,[84]=61,[85]=61},
}}}
