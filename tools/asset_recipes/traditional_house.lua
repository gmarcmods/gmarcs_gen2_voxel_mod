-- Tatami rooms, Kurt's workshop, the barn and Dance Theater.
local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local P=dofile(root..'/historic_primitives.lua');local s=P.s;local assets={}
local function add(a) assets[#assets+1]=a;return a end
add(P.table('traditional_low_table',{{35,34,34,36},{66,21,21,67},{66,21,21,67},{51,50,50,52}},4))
add(P.table('traditional_small_table',{{35,36},{51,52}},4))
add(P.table('traditional_workbench',{{35,34,34,34,34,34,34,36},{51,50,50,12,13,50,7,52},{66,21,21,50,50,28,29,67},{35,36,81,81,81,81,81,38}},8))
add(P.table('traditional_side_table',{{35,34,34,36},{51,50,50,52}},4))
add(P.cabinet('traditional_workbench_side',{{51,52},{51,52},{51,52},{51,52}},24,16))
add(P.cabinet('traditional_double_bookcase',{{35,36},{62,63},{62,63},{24,25}},4,10))
add(P.table('traditional_shop_table',{{35,36},{66,67},{66,67},{51,52}},4))
local tea=add(P.table('traditional_theater_table',{{43,44,45,75},{59,60,61,91}},4))
-- Cushions sit directly on tatami, with a rounded stitched outline.
local cushion=add(P.blank('traditional_floor_cushion',{{2,3},{18,19}}))
for x=1,14 do for z=1,14 do local y=(x>2 and x<13 and z>2 and z<13) and 2 or 1
 for yy=0,y do if not ((x==1 or x==14) and (z==1 or z==14)) then P.put(cushion,x,yy,z,z*16+x) end end
end end
add(P.cabinet('traditional_bookcase',{{35,36},{62,63},{24,25}},4,10))
add(P.cabinet('traditional_cupboard',{{35,36},{30,31},{46,47},{24,25}},4,10))
add(P.cabinet('traditional_tall_cabinet',{{35,36},{41,42},{57,58},{82,83}},4,10))
add(P.cabinet('traditional_low_cabinet',{{35,36},{8,9},{82,83}},4,10))
add(P.cabinet('traditional_shop_shelf',{{6,7,7,32},{22,23,23,48},{33,39,39,40},{49,55,55,56}},4,12))
local radio=add(P.cabinet('traditional_radio',{{10,11},{26,27}},3,8))
for y=13,18 do P.put(radio,13,y,1,3*16+13) end
add({id='traditional_wall_picture',tiles={{71,72,73,74},{87,88,89,90}},surfaces={s({0,0,32,16},'vertical',0,16)}})
add({id='traditional_theater_portrait',tiles={{78,79},{94,94}},surfaces={s({0,0,16,16},'vertical',8,16)}})
local stageRows={}
for y=1,8 do stageRows[y]={};for x=1,24 do stageRows[y][x]=y==8 and ((x==3 or x==4 or x==21 or x==22) and 95 or 15) or 80 end end
local stage=add({id='traditional_theater_stage',support=8,tiles=stageRows,surfaces={s({0,0,192,64},'horizontal',7,1)},voxelEdits={}})
-- Fascia is vertical and the two entry bays have actual treads.
for x=0,191 do local stair=x>=16 and x<32 or x>=160 and x<176
 for z=56,63 do local top=stair and math.max(0,7-math.floor((z-56)/2)*2) or 7
 for y=0,top do P.put(stage,x,y,z,63*192+x) end
 if stair and top<7 then stage.voxelEdits[#stage.voxelEdits+1]={x=x,y=7,z=z,remove=true} end
 end
end
-- Solid stage front rises eight pixels; its approach steps use the engine's
-- staircase profile, while the rest of the wooden platform remains level.
local repair=dofile(root..'/azalea_repairs.lua')
for _,a in ipairs(assets)do repair(a)end
-- Whole furniture patterns claim before their reusable component sprites.
for i,a in ipairs(assets) do a._order=i end
table.sort(assets,function(a,b) local aa,bb=#a.tiles*#a.tiles[1],#b.tiles*#b.tiles[1];return aa==bb and a._order<b._order or aa>bb end)
for _,a in ipairs(assets) do a._order=nil end
local entrance=dofile(root..'/tower_entrance_repairs.lua')
local extra=entrance.extras().TILESET_TRADITIONAL_HOUSE
for i=#extra,1,-1 do table.insert(assets,1,extra[i])end
return {tilesets={TILESET_TRADITIONAL_HOUSE={assets=assets,planter_spray=false,
 classes={traditional_wall={base='wall',height=16,art='flat'},traditional_stage={base='wall',height=8,art='flat'}},
 pins={ground={0,1,4,14,16,20,37,38,54,68,69,70,80,81,84,85,86}, -- dirt strip, rugs, tatami seams and floor shadows
 traditional_wall={17,64,65}, -- continuous wood wall and barn slats
 traditional_stage={15,95}, -- Dance Theater platform (wood flooring elsewhere shares this tile)
 stair_down_n={76,77,92,93}, -- passage behind the Tin Tower entrance
 },prop_ground={[2]=69,[3]=69,[18]=69,[19]=69},
}}}
