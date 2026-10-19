-- Facility's seven maps share machinery, offices and research furniture.
local function s(r,o,h,d,z) return {rect=r,orientation=o,height=h,depth=d,z=z or 0} end
local function blank(id,tiles)
 return {id=id,tiles=tiles,surfaces={s({0,0,1,1},'vertical',0,1)},voxelEdits={{x=0,y=0,z=0,remove=true}}}
end
local function put(a,x,y,z,i) a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=i,region=1} end
local assets={}
local function add(a) assets[#assets+1]=a;return a end
local function cabinet(id,tiles)
 local W,H=#tiles[1]*8,#tiles*8
 return add({id=id,tiles=tiles,surfaces={s({0,0,W,8},'horizontal',H-8,1),s({0,8,W,H-8},'vertical',0,10)}})
end
cabinet('facility_server_cabinet',{{64,66},{10,11},{10,11},{26,27}})
cabinet('facility_file_cabinet',{{64,66},{40,41},{40,41},{42,43}})
cabinet('facility_bookshelf',{{64,66},{40,41},{40,41},{40,41}})
cabinet('facility_research_terminal',{{92,93},{94,95},{22,23}})
local desk=add({id='facility_computer_desk',tiles={{2,3,4,5},{18,19,20,21},{6,7,8,9}},surfaces={
 s({0,16,32,8},'vertical',0,14), -- drawers support the worktop
 s({0,0,32,16},'horizontal',8,1),
 s({1,1,14,9},'vertical',10,6), -- deep CRT body above the desk
 s({2,10,12,4},'horizontal',9,1,7), -- keyboard lies on the worktop
 s({20,0,11,14},'vertical',9,8), -- equipment tower
 },voxelEdits={}})
-- Restore the continuous wood top beneath pixels moved into equipment.
for x=0,31 do for z=0,15 do put(desk,x,8,z,14*32+17) end end
add({id='facility_paper_desk',tiles={{64,65,65,66},{80,72,73,82},{6,7,8,9}},surfaces={s({0,0,32,16},'horizontal',8,1),s({0,16,32,8},'vertical',0,14)}})
local function tableAsset(id,tiles)
 local W=#tiles[1]*8
 local a=add({id=id,tiles=tiles,surfaces={s({0,0,W,24},'horizontal',8,2)},voxelEdits={}})
 for _,x0 in ipairs({1,W-4}) do for x=x0,x0+2 do for y=0,7 do for _,z0 in ipairs({0,21}) do for z=z0,z0+2 do
  put(a,x,y,z,24*W+x)
 end end end end end
 return a
end
local meeting={{64,65,65,65,65,66},{80,81,81,81,81,82},{80,81,81,81,81,82},{83,58,58,58,58,84}}
tableAsset('facility_meeting_table',meeting)
tableAsset('facility_small_table',{{64,65,65,66},{80,81,81,82},{80,72,73,82},{83,58,58,84}})
local chair=add({id='facility_chair',tiles={{14,15},{30,31}},surfaces={s({2,2,12,6},'vertical',5,2),s({2,8,12,5},'horizontal',4,2,2)},voxelEdits={}})
for _,x in ipairs({3,12}) do for _,z in ipairs({2,6}) do for y=0,3 do put(chair,x,y,z,14*16+x) end end end
local sofa=add({id='facility_sofa',tiles={{35,36,36,37},{87,88,88,89}},surfaces={
 s({2,0,28,5},'vertical',5,3),s({4,5,24,8},'horizontal',3,3,3),
 s({0,5,4,9},'horizontal',3,6,3),s({28,5,4,9},'horizontal',3,6,3)},voxelEdits={}})
for _,x in ipairs({3,28}) do for _,z in ipairs({2,10}) do for y=0,2 do put(sofa,x,y,z,14*32+x) end end end
local tree=add(blank('facility_potted_tree',{{44,45},{60,61},{46,47},{62,63}}))
for y=0,7 do for x=2,13 do for z=2,13 do put(tree,x,y,z,(31-y)*16+x) end end end
for y=8,17 do for x=7,9 do for z=7,9 do put(tree,x,y,z,19*16+x) end end end
for y=15,30 do for x=0,15 do for z=0,15 do
 if ((x-7.5)/8)^2+((y-22)/9)^2+((z-7.5)/8)^2<=1 then
  put(tree,x,y,z,math.max(2,math.min(14,30-y))*16+x)
 end
end end end
local function pipe(id,north)
 local a=add(blank(id,north and {{12,13}} or {{56},{57}}))
 for along=0,7 do for _,c in ipairs({3,11}) do for across=c-2,c+2 do for y=0,4 do
  if (across-c)^2+(y-2)^2<=4 then
   local x,z=north and across or along,north and along or across
   put(a,x,y,z,north and (along*16+across) or (across*8+along))
  end
 end end end end
end
pipe('facility_pipe_n',true);pipe('facility_pipe_e',false)
-- Each bank matches the complete machine drawing. Repeated steel columns
-- become cylinders above the control cabinets, with recessed spaces between.
local function bank(id,rows)
 local a=add(blank(id,rows));local W=#rows[1]*8
 a.surfaces[#a.surfaces+1]=s({0,16,W,16},'vertical',0,14)
 for col,tile in ipairs(rows[1]) do
  local x0=(col-1)*8
  if tile==69 then
   for dx=0,7 do
    local radius=math.sqrt(math.max(0,1-((dx-3.5)/4)^2))*5
    local depth=math.max(1,math.floor(radius*2))
    a.surfaces[#a.surfaces+1]=s({x0+dx,0,1,16},'vertical',16,depth,7-math.floor(depth/2))
   end
  else
   a.surfaces[#a.surfaces+1]=s({x0,0,8,16},'vertical',16,10,2)
  end
 end
end
bank('facility_power_bank',{
 {69,69,70,69,69,69,70,69,69,70,69,59},{85,85,86,85,85,85,86,85,85,86,85,59},
 {10,11,75,10,10,11,75,10,74,75,74,59},{26,27,91,26,26,27,91,26,90,91,90,59}})
bank('facility_power_bank_aux',{
 {69,70,69,59,69,69,70,69,69,70,69,59},{85,86,85,59,85,85,86,85,85,86,85,59},
 {74,75,74,59,10,11,75,10,74,75,74,59},{90,91,90,59,26,27,91,26,90,91,90,59}})
bank('facility_rocket_bank',{
 {69,69,70,69,69,70,69,69,69,70,69,59},{85,85,86,85,85,86,85,85,85,86,85,59},
 {10,11,75,10,11,75,10,11,74,75,74,59},{26,27,91,26,27,91,26,27,90,91,90,59}})
local rocket=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/rocket_furniture.lua')
rocket.apply({buildings={TILESET_FACILITY=assets,TILESET_UNDERGROUND={}}})
return {tilesets={TILESET_FACILITY={
 classes={facility_wall={base='wall',height=16,art='flat'}},
 pins={ground={0,1,28,29,38,39,55}, -- alternating office floor, machine room and entry rug
 facility_wall={34,64,65,66,76,77,78,80,82}, -- continuous 16px partition footprint
 stair_e={16,17,32,33}, -- drawn west-to-east ascending flight
 stair_down_e={48,49,24,25}, -- its descending counterpart
 },
 assets=assets,planter_spray=false,
}}}
