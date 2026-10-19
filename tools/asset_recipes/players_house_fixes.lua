-- Complete sprites from all six maps sharing this tileset.
local function s(rect,o,h,d,z) return {rect=rect,orientation=o,height=h,depth=d,z=z or 0} end
local function cabinet(id,tiles,top,depth)
 local H=#tiles*8
 return {id=id,tiles=tiles,surfaces={s({0,0,16,top},'horizontal',H-top,1),s({0,top,16,H-top},'vertical',0,depth)}}
end
local assets={
 cabinet('house_tv_cabinet',{{6,7},{22,23},{8,9}},4,10),
 cabinet('house_drawers',{{14,15},{58,59}},8,8),
 cabinet('house_bookcase_left',{{14,15},{30,31},{46,47},{24,25}},8,8),
 cabinet('house_bookcase_right',{{14,15},{46,47},{8,9},{58,59}},8,8),
 -- The two wall-textured rows beneath the counter are its drawn apron,
 -- not another room-height wall. Claim them with the complete counter.
 {id='house_partition_counter',tiles={{37,53},{37,53},{37,53},{37,53},{37,53},{51,52},{17,17},{17,17}},
  surfaces={s({0,0,16,48},'horizontal',0,9)}},
 {id='house_computer_desk',tiles={{32,33},{48,49},{12,13},{28,29}},surfaces={
  s({0,0,16,4},'horizontal',22,1),s({0,4,16,12},'vertical',10,10),
  s({0,16,16,5},'horizontal',10,1,10),s({0,21,16,3},'vertical',8,16),
  s({0,24,16,2},'vertical',6,16),
  s({1,26,4,4},'vertical',2,2,14),s({11,26,4,4},'vertical',2,2,14)},voxelEdits={}},
}
local desk=assets[#assets]
for x=0,15 do for z=4,9 do desk.voxelEdits[#desk.voxelEdits+1]={x=x,y=22,z=z,i=48+x,region=1} end end
for _,x0 in ipairs({1,11}) do for x=x0,x0+3 do for y=2,5 do for z=0,1 do
 desk.voxelEdits[#desk.voxelEdits+1]={x=x,y=y,z=z,i=(31-y)*16+x,region=6}
end end end end
assets[#assets+1]=cabinet('house_tv_cupboard',{{6,7},{22,23},{24,25}},4,10)
assets[#assets+1]={id='house_tv_console',tiles={{6,7},{22,23},{74,75},{90,91}},surfaces={
 s({0,0,16,4},'horizontal',12,1),s({0,4,16,12},'vertical',0,10),
 -- Console sits on the floor ahead of the TV; controller is lower still.
 s({3,16,10,10},'horizontal',0,3,10),s({8,26,8,6},'horizontal',0,2,20)}}
-- Short and medium tables use the same apron/legs as the dining table,
-- but have fewer top rows. They must not become full-height solid boxes.
for _,rows in ipairs({2,3}) do
 local tiles={{35,34,34,36}}
 if rows==3 then tiles[#tiles+1]={37,21,21,53} end
 tiles[#tiles+1]={51,50,50,52};tiles[#tiles+1]={28,64,64,29}
 local top=rows*8
 local a={id=rows==2 and 'house_short_table' or 'house_medium_table',tiles=tiles,
  surfaces={s({0,0,32,top},'horizontal',6,1),s({0,top,32,2},'vertical',4,top),
   s({1,top+2,5,4},'vertical',0,2,top-2),s({26,top+2,5,4},'vertical',0,2,top-2)},voxelEdits={}}
 for _,x0 in ipairs({1,26}) do for x=x0,x0+4 do for y=0,3 do for z=0,1 do
  a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=(top+5-y)*32+x,region=3}
 end end end end
 assets[#assets+1]=a
end
-- Paired columns precede singles; both form a thin, full-height wall.
assets[#assets+1]={id='house_wall_window',tiles={{44,45},{17,17}},
 surfaces={s({0,0,16,16},'vertical',0,2)}}
for _,count in ipairs({2,1}) do
 local a={id=count==2 and 'house_wall_pair' or 'house_wall_single',tiles={},
  surfaces={s({0,0,8,8},'vertical',0,2)},voxelEdits={}}
 for i=1,count do a.tiles[i]={17} end
 for y=8,15 do for x=0,7 do for z=0,1 do
  a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=(7-y%8)*8+x,region=1}
 end end end
 assets[#assets+1]=a
end
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
return {tilesets={TILESET_PLAYERS_HOUSE={assets=assets,
 prop_ground=dofile(dir..'/furniture_floors.lua').tilesets.TILESET_PLAYERS_HOUSE.prop_ground}}}
