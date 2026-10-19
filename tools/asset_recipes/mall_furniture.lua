-- Source-backed department-store fixtures, anchored to native collision cells.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
local P=dofile(dir..'/historic_primitives.lua');local M={}
local function reset(a)a.surfaces={{rect={0,0,1,1},orientation='vertical',height=0,depth=1,z=0}};a.voxelEdits={{x=0,y=0,z=0,remove=true}}end
local function tex(a,x,y)return math.max(0,math.min(#a.tiles*8-1,y))*#a.tiles[1]*8+math.max(0,math.min(#a.tiles[1]*8-1,x))end
local function stock(a,x0,W)
 local color=tex(a,x0+2,2)
 P.box(a,x0,0,15,W,24,2,color)
 for _,x in ipairs({x0,x0+W-2})do P.box(a,x,0,0,2,24,32,color)end
 for _,y in ipairs({0,3,11,19,24})do P.box(a,x0,y,0,W,1,32,function(x,_,z)return tex(a,x,2+(z%4))end)end
 for tier=0,1 do for index,x in ipairs({x0+2,x0+5,x0+9,x0+12})do
  local bottom=4+tier*8;local h=4+(index+tier+1)%3
  for _,z in ipairs({3,24})do P.box(a,x,bottom,z,2,h,5,function(xx,yy)return tex(a,xx,11+tier*7+(yy-bottom)%3)end)end
 end end
end
local counters={mart_counter=true,mart_counter_end=true,mart_counter_north_run=true,mart_counter_south_run=true,mart_counter_north_corner=true,mart_counter_south_corner=true}
function M.repair(a)
 local id=a.id;local W,H=#a.tiles[1]*8,#a.tiles*8
 if counters[id]or id:match('^mart_counter_tile_')then
  reset(a);a.support=7
  for x=0,W-1 do for z=0,(H==8 and 7 or 15)do for y=0,6 do
   local sy=y==6 and math.floor(z/2)or math.min(H-1,H-1-y)
   P.put(a,x,y,z,tex(a,x,sy))
  end end end
 elseif id=='mart_shelf'or id=='mart_display'then
  reset(a);stock(a,0,16)
  if id=='mart_display'then
   -- The right half is the original red Pokeball-logo counter, not shelves.
   for x=16,31 do for z=16,31 do for y=0,16 do
    if y==16 or x==16 or x==31 or z==16 or z==30 then
     P.put(a,x,y,z,tex(a,x,y==16 and math.floor((z-16)/2)or 23-y))
    end
   end end end
   for x=20,28 do for y=4,11 do if ((x-24)/5)^2+((y-8)/4)^2<=1 then P.put(a,x,y,31,tex(a,x,23-y))end end end
  end
 elseif id=='mart_blue_rack'then
  reset(a)
  P.box(a,1,0,0,14,3,32,tex(a,5,28))
  -- A long, low glass island covers both blocked floor cells.
  for _,x in ipairs({2,3,12,13})do P.box(a,x,3,0,1,10,32,tex(a,x,4))end
  for _,z in ipairs({0,1,30,31})do P.box(a,2,3,z,12,10,1,tex(a,5,3))end
  P.box(a,4,11,2,8,1,28,function(x,_,z)return tex(a,x,math.min(23,z))end)
  for z=4,26,7 do P.box(a,5,4,z,5,4,3,tex(a,6,z))end
 elseif id=='mart_glass_cabinet'or id=='mart_vending_machine'then
  reset(a);local top=27;local back=id=='mart_glass_cabinet'and 0 or 16;local depth=32-back;local color=tex(a,2,2)
  P.box(a,0,0,back,16,top+1,2,color)
  for _,x in ipairs({0,14})do P.box(a,x,0,back,2,top+1,depth,color)end
  P.box(a,0,0,back,16,2,depth,color);P.box(a,0,top,back,16,1,depth,tex(a,4,3))
  for x=2,13 do for y=2,top-1 do
   local slot=id=='mart_vending_machine'and x>=4 and x<=11 and y>=3 and y<=6
   local inset=slot and 27 or(x>=3 and x<=12 and y>=8 and y<=23)and 29 or 31
   P.put(a,x,y,inset,tex(a,x,31-y))
  end end
  if id=='mart_vending_machine'then
   for y=11,20,3 do P.box(a,12,y,30,2,2,2,tex(a,12,31-y))end
   P.box(a,4,2,28,8,1,4,tex(a,5,29))
  else
   P.box(a,7,11,30,2,5,2,tex(a,7,17))
  end
 elseif id=='mart_register'then
  reset(a);a.support=7
  P.box(a,0,0,0,16,7,16,tex(a,8,14))
  P.box(a,2,7,2,12,7,5,function(x,y)return tex(a,x,13-y)end)
  P.box(a,1,7,8,14,1,6,function(x,_,z)return tex(a,x,12+math.floor((z-8)/2))end)
  for x=3,11,3 do for z=9,11,2 do P.put(a,x,8,z,tex(a,x,14))end end
 elseif id=='mart_north_seat'or id=='mart_south_seat'then
  reset(a);local back=id=='mart_north_seat'and 1 or 12
  P.box(a,2,5,3,12,3,10,function(x,_,z)return tex(a,x,z%8)end)
  P.box(a,2,7,back,12,7,3,function(x,y)return tex(a,x,math.max(0,13-y))end)
  for _,x in ipairs({1,13})do P.box(a,x,7,3,2,3,10,tex(a,5,3))end
  for _,x in ipairs({3,11})do for _,z in ipairs({4,11})do P.box(a,x,0,z,2,5,2,tex(a,2,13))end end
 elseif id=='mart_hedge'or id=='mart_hedge_cap'then
  reset(a);P.box(a,1,0,0,14,4,8,tex(a,7,7))
  for _,x in ipairs({4,9,12})do P.ellipsoid(a,x,7,3.5,3,4,3.5,function(xx,yy,zz)return tex(a,xx,math.max(0,math.min(6,10-yy+zz%2)))end)end
 elseif id=='mart_dept_window'or id=='mart_counter_window'or id=='mart_elevator_door'or id=='mart_directory'or id=='mart_wall_panel'or id=='mart_wall_panel_reverse'then
  reset(a);local poster=id=='mart_directory';local bottom,top=poster and 8 or 0,poster and 22 or 24
  for x=0,15 do for y=bottom,top do
   local sy=math.floor((top-y)*16/(top-bottom+1));P.put(a,x,y,13,tex(a,x,sy))
   if x<2 or x>13 or y==bottom or y>=top-1 then P.put(a,x,y,14,tex(a,1,1));P.put(a,x,y,15,tex(a,1,1))end
  end end
  if id=='mart_dept_window'or id=='mart_counter_window'then
   P.box(a,7,0,14,2,24,1,tex(a,0,1));P.box(a,0,7,14,16,1,2,tex(a,0,1))
  elseif id=='mart_wall_panel'or id=='mart_wall_panel_reverse'then
   P.box(a,9,10,14,4,5,2,function(x,y)return tex(a,x,8+(y-10))end)
  elseif id=='mart_elevator_door'then
   P.box(a,7,1,14,2,21,1,tex(a,0,0))
  end
  if id=='mart_counter_window'then
   for x=0,15 do for z=8,15 do for y=0,6 do P.put(a,x,y,z,tex(a,x,8+z%8))end end end
  end
 elseif id=='underground_crate'then
  reset(a)
  for x=0,15 do for z=0,15 do for y=0,13 do
   if x<2 or x>13 or z<2 or z==14 or y==0 or y==13 then
    local sy=y==13 and math.floor(z/2)or 15-math.floor(y*8/14)
    P.put(a,x,y,z,tex(a,x,sy))
   end
  end end end
  -- Raised diagonal braces preserve the native crate's crossed-plank design.
  for x=2,13 do for _,y in ipairs({x-1,14-x})do P.put(a,x,y,15,tex(a,x,15-math.floor(y/2)))end end
 else return a,false end
 return a,true
end
function M.extras()
 local list={
  P.blank('mart_counter_north_run',{{59},{26}}),
  P.blank('mart_counter_south_run',{{30},{26}}),
  P.blank('mart_counter_north_corner',{{42,59},{62,63}}),
  P.blank('mart_counter_south_corner',{{46,30},{24,26}}),
  P.blank('mart_wall_panel',{{10,17},{73,73}}),
  P.blank('mart_wall_panel_reverse',{{17,10},{73,73}}),
  P.blank('mart_counter_window',{{14,15},{42,43}}),
 }
 -- Corners must claim before their shorter run patterns.
 list[1],list[3]=list[3],list[1];list[2],list[4]=list[4],list[2]
 for _,a in ipairs(list)do M.repair(a)end
 return list
end
function M.fallbacks()
 local list={}
 for _,tile in ipairs({24,25,26,30,42,43,46,47,59,62,63})do
  local a=P.blank('mart_counter_tile_'..tile,{{tile}});M.repair(a);list[#list+1]=a
 end
 return list
end
return M
