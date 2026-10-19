local p=debug.getinfo(1,'S').source:sub(2):match('(.+)/');local H=dofile(p..'/public_interior_shapes.lua');local s=H.s
local desk=H.desk('radio_office_desk',{{5,7,36,6},{21,22,76,77}})
-- Source telephone sits above the wooden worktop, never on the floor.
for x=16,23 do for z=1,5 do for y=10,16 do H.put(desk,x,y,z,(16-y)*32+x) end end end
local assets={desk,H.desk('radio_document_desk',{{5,7,90,36},{21,23,23,64}}),
 H.box('radio_pc',{{46,47},{62,63},{58,59}},10),
 H.box('radio_reception_terminal',{{86,87},{88,89},{76,77}},10),
 H.plant('radio_plant',{{70,71},{72,73},{72,73},{74,75}}),
 H.stool('radio_stool',{{44,45},{60,61}}),H.stool('radio_studio_stool',{{39,40},{55,56}}),
 H.box('radio_file_cabinet',{{34,35},{50,51},{50,51}},10),
 H.box('radio_storage',{{48,49},{26,27},{26,27},{10,11}},10),
 {id='radio_wall_notice',tiles={{3,4},{19,20}},surfaces={s({0,0,16,16},'vertical',0,8)}},
 {id='radio_studio_window',tiles={{48,49},{32,33},{32,33},{41,42}},surfaces={s({0,0,16,32},'vertical',0,6)}},
}
local studio=H.desk('radio_studio_table',{{37,38,7,6},{53,54,25,9},{8,25,25,9},{78,79,25,9},{94,95,25,9},{21,24,24,22}})
studio.surfaces={s({0,0,32,40},'horizontal',8,2)}
for _,x in ipairs({2,28}) do for z=35,37 do for y=0,7 do H.put(studio,x,y,z,45*32+x) end end end
-- Papers lie just above the tabletop; a microphone rises on a thin stem.
for x=2,13 do for z=24,36 do H.put(studio,x,10,z,(24+z-24)*32+x) end end
for y=10,20 do H.put(studio,9,y,6,4*32+9) end
for x=6,11 do for y=19,23 do for z=4,7 do H.put(studio,x,y,z,5*32+8) end end end
assets[#assets+1]=studio

assets[#assets+1]=H.plant('radio_short_plant',{{70,71},{72,73}})
assets[#assets+1]=H.stool('radio_blue_table',{{82,83},{80,81}})
assets[#assets+1]=H.stool('radio_blue_telephone_table',{{82,52},{80,81}})
assets[#assets+1]={id='radio_window_partition',tiles={{48,49},{32,33},{65,33},{64,42}},surfaces={s({0,0,16,32},'vertical',0,6)}}
assets[#assets+1]={id='radio_table_window',tiles={{48,49},{32,33},{32,33}},surfaces={s({0,0,16,24},'vertical',8,6)}}
assets[#assets+1]={id='radio_upper_window',tiles={{48,49},{32,33}},surfaces={s({0,0,16,16},'vertical',16,6)}}
local details=dofile(p..'/radio_details.lua')
for _,a in ipairs(assets)do details.repair(a)end
for _,a in ipairs(details.extras())do assets[#assets+1]=a end
return {tilesets={TILESET_RADIO_TOWER={assets=assets,planter_spray=false,
 classes={radio_wall={base='wall',height=16,art='flat'},radio_partition={base='wall',height=10,art='flat'}},
 pins={ground={1,2,18,25,66,67},radio_wall={16,17,32,33,41,42,48,49,65},radio_partition={5,6,7,8,9,21,22,23,24,36,64,84,85,90},
 stair_w={12,13,28,29},stair_down_e={14,15,30,31},void={0,43,57,68,69,91,92,93}},
 prop_ground={[70]=1,[71]=1,[72]=1,[73]=1,[74]=1,[75]=1,[44]=1,[45]=1,[60]=1,[61]=1,[39]=66,[40]=67,[55]=66,[56]=67},
}}}
