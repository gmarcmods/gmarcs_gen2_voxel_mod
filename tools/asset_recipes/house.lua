-- Authored against the seven layouts in the installed Gold house tileset.
-- Preserve the six existing asset IDs when refining their geometry.
local function s(r,o,h,d,z) return {rect=r,orientation=o,height=h,depth=d,z=z or 0} end
local assets={}
local function add(a) assets[#assets+1]=a;return a end
local function put(a,x,y,z,i) a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=i,region=1} end
local function blank(id,tiles)
 return {id=id,tiles=tiles,surfaces={s({0,0,1,1},'vertical',0,1)},voxelEdits={{x=0,y=0,z=0,remove=true}}}
end
local function legs(a,W,D,i)
 for _,x0 in ipairs({1,W-4}) do for _,z0 in ipairs({1,D-4}) do
  for x=x0,x0+2 do for z=z0,z0+2 do for y=0,7 do put(a,x,y,z,i) end end end
 end end
end
local function tableAsset(id,tiles)
 local W,D=#tiles[1]*8,(#tiles-1)*8
 local a=add({id=id,tiles=tiles,surfaces={s({0,0,W,D},'horizontal',8,2)},voxelEdits={}})
 legs(a,W,D,(D+2)*W+2)
 return a
end
local large={{38,39,39,39,39,39,39,41},{54,47,47,47,47,47,47,57},
 {54,47,47,34,35,47,47,57},{54,47,47,82,83,47,47,57},
 {54,47,47,37,53,47,47,57},{54,47,47,47,47,47,47,57},
 {5,47,47,47,47,47,47,21},{60,58,58,58,58,58,58,59}}
local trophy=tableAsset('house_trophy_table',large)
-- Replace the flat statue drawing with wood before building its pedestal.
for x=24,39 do for z=16,39 do for y=8,9 do put(trophy,x,y,z,10*64+20) end end end
for x=26,37 do for z=23,32 do for y=10,17 do put(trophy,x,y,z,(39-(y-10))*64+x) end end end
for x=25,38 do for z=23,34 do for y=18,31 do
 if ((x-31.5)/7)^2+((z-28.5)/6)^2+((y-24)/8)^2<=1 then
  put(trophy,x,y,z,math.max(16,math.min(31,45-y))*64+x)
 end
end end end
-- The small bird head and beak extend above the rounded body.
for x=30,37 do for z=25,32 do for y=29,35 do
 if ((x-33.5)/4)^2+((z-28.5)/4)^2+((y-32)/4)^2<=1 then put(trophy,x,y,z,(51-y)*64+x) end
end end end
for x=37,39 do for z=27,29 do for y=31,32 do put(trophy,x,y,z,19*64+37) end end end

local book=tableAsset('house_book_table',{{38,39,39,41},{70,71,47,57},{86,87,47,21},{60,58,58,59}})
for x=0,15 do for z=8,23 do for y=8,9 do put(book,x,y,z,10*32+20) end end end
for x=1,14 do for z=9,20 do
 local sy=16+math.floor((z-9)*8/12)
 put(book,x,10,z,sy*32+x)
 if x==7 or x==8 then put(book,x,11,z,sy*32+x) end
end end
tableAsset('common_house_table',{{38,39,39,41},{54,47,47,57},{5,47,47,21},{60,58,58,59}})
tableAsset('house_flower_shop_table',{{50,39,39,51},{54,47,47,57},{60,58,58,59}})
local counter=add({id='house_counter_l',tiles={{39,39,39,51},{58,58,54,57},
 {1,1,54,57},{1,1,54,57},{1,1,54,57},{1,1,54,57},{1,1,54,57},{1,1,54,57}},
 surfaces={s({0,0,32,8},'horizontal',8,2),s({16,8,16,56},'horizontal',8,2,8)},voxelEdits={}})
for _,p in ipairs({{1,1},{28,1},{17,59},{28,59}}) do
 for x=p[1],p[1]+2 do for z=p[2],p[2]+2 do for y=0,7 do put(counter,x,y,z,4*32+20) end end end
end
local stool=add({id='common_house_stool',tiles={{2,3},{18,19}},surfaces={},voxelEdits={}})
for row,span in ipairs({{5,6},{3,10},{2,12},{2,12},{2,12},{2,12}}) do
 stool.surfaces[#stool.surfaces+1]=s({span[1],row+4,span[2],1},'horizontal',4,2,row-1)
end
for _,x in ipairs({3,12}) do for _,z in ipairs({1,4}) do for y=0,3 do put(stool,x,y,z,(15-y)*16+x) end end end

local function cabinet(id,tiles)
 return add({id=id,tiles=tiles,surfaces={s({0,0,16,4},'horizontal',24,1),s({0,4,16,24},'vertical',0,10)},voxelEdits={}})
end
local shelf=cabinet('house_bookshelf',{{50,51},{48,49},{14,15},{60,59}})
cabinet('house_cabinet',{{50,51},{14,15},{14,15},{30,31}})
cabinet('house_bookshelf_closed',{{50,51},{48,49},{14,15},{30,31}})
cabinet('house_bookshelf_double',{{50,51},{48,49},{48,49},{30,31}})
-- Shelf openings sit one voxel behind their frame.
for _,band in ipairs({{7,10},{16,19}}) do for sy=band[1],band[2] do for x=2,13 do
 shelf.voxelEdits[#shelf.voxelEdits+1]={x=x,y=27-sy,z=9,remove=true}
end end end
local function appliance(id,tiles,depth)
 local a=add({id=id,tiles=tiles,surfaces={s({0,16,16,5},'vertical',3,depth),
  s({0,4,16,12},'vertical',8,depth),s({0,0,16,4},'horizontal',20,1)},voxelEdits={}})
 for _,x0 in ipairs({1,12}) do for _,z0 in ipairs({1,depth-3}) do
  for x=x0,x0+2 do for z=z0,z0+1 do for y=0,2 do put(a,x,y,z,19*16+x) end end end
 end end
 for x=0,15 do for z=0,depth-1 do put(a,x,20,z,id=='common_house_radio' and 5*16+8 or 2*16+x) end end
 if id=='common_house_radio' then for y=21,24 do put(a,13,y,2,2*16+13) end end
 return a
end
appliance('common_house_tv',{{6,7},{22,23},{30,31}},10)
appliance('common_house_radio',{{12,13},{28,29},{30,31}},8)
local pc=add({id='house_computer',tiles={{64,65},{32,33},{66,67}},surfaces={
 s({0,0,16,16},'vertical',8,10),s({0,16,16,8},'horizontal',8,2,10)},voxelEdits={}})
for x=2,13 do for z=2,15 do for y=0,7 do put(pc,x,y,z,20*16+8) end end end

-- Each decoration includes its wall backing: its face joins the 16px-deep
-- wall course instead of leaving an opening or a duplicate picture on top.
add({id='house_window',tiles={{36,74},{52,44}},surfaces={s({0,0,16,16},'vertical',0,16)}})
add({id='house_picture',tiles={{45,46},{61,62}},surfaces={s({0,0,16,16},'vertical',0,16)}})
add({id='house_wall_notice',tiles={{68,69},{0,0}},surfaces={s({0,0,16,16},'vertical',0,16)}})

local tree=add(blank('house_potted_tree',{{10,11},{8,9},{26,27},{24,25}}))
for y=0,6 do for x=2,13 do for z=2,13 do
 if (x-7.5)^2+(z-7.5)^2<=(4+y*.3)^2 then put(tree,x,y,z,(31-y)*16+x) end
end end end
for x=7,9 do for z=7,9 do for y=7,17 do put(tree,x,y,z,21*16+x) end end end
for x=0,15 do for z=0,15 do for y=13,30 do
 if ((x-7.5)/8)^2+((z-7.5)/8)^2+((y-22)/10)^2<=1 then
  local above=((x-7.5)/8)^2+((z-7.5)/8)^2+((y+1-22)/10)^2
  local sy=above>1 and z or 30-y
  put(tree,x,y,z,math.max(2,math.min(13,sy))*16+math.max(3,math.min(12,x)))
 end
end end end
local function flowerBox(id,long)
 local tiles=long and {{42,43},{84,85},{84,85},{94,95}} or {{42,43},{94,95}}
 local H,D=#tiles*8,long and 24 or 12
 local a=add({id=id,tiles=tiles,surfaces={s({1,H-8,14,8},'vertical',0,D)},voxelEdits={}})
 for x=2,13 do for z=1,D-2 do for y=8,10 do
  put(a,x,y,z,(2+z%5)*16+9+x%4)
 end end end
 local blooms=long and {{4,4,0},{11,12,8},{11,20,16}} or {{4,4,0}}
 for _,b in ipairs(blooms) do for x=b[1]-2,b[1]+2 do for z=b[2]-2,b[2]+2 do for y=10,14 do
  if (x-b[1])^2+(z-b[2])^2+(y-12)^2<=7 then
   put(a,x,y,z,((y>=13 or x==b[1] and z==b[2]) and 3 or 4)*16+4)
  end
 end end end end
 return a
end
flowerBox('house_long_flower_box',true);flowerBox('house_flower_box',false)

local function memorial(id,flowers)
 local a=add(blank(id,flowers and {{55,40},{56,63},{1,79}} or {{55,40},{56,78}}))
 for x=1,14 do for z=1,9 do for y=0,2 do put(a,x,y,z,13*16+math.min(x,7)) end end end
 for y=3,17 do
  local inset=math.max(2,y-12)
  for x=inset,15-inset do for z=3,7 do
   local sx=flowers and (x>7 and 15-x or x) or x
   put(a,x,y,z,(17-y)*16+sx)
  end end
 end
 if flowers then
  for x=11,14 do for z=12,15 do for y=0,4 do put(a,x,y,z,(22-y)*16+x) end end end
  for y=5,9 do put(a,12,y,13,13*16+12) end
  for x=10,14 do for z=11,15 do
   if (x-12)^2+(z-13)^2<=5 then put(a,x,9,z,11*16+12) end
  end end
 end
 return a
end
memorial('house_memorial_flowers',true);memorial('house_memorial',false)

local ground={[2]=1,[3]=1,[18]=1,[19]=1,[10]=1,[11]=1,[8]=1,[9]=1,[26]=1,[27]=1,[24]=1,[25]=1,
  [42]=1,[43]=1,[84]=1,[85]=1,[94]=1,[95]=1,[55]=1,[40]=1,[56]=1,[78]=1,[63]=1,[79]=1}
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
for tile,floor in pairs(dofile(dir..'/furniture_floors.lua').tilesets.TILESET_HOUSE.prop_ground)do ground[tile]=floor end

return {tilesets={TILESET_HOUSE={
 classes={house_wall={base='wall',height=16,art='flat'},house_counter={base='wall',height=10,art='flat'}},
 pins={ground={1,4,20,80,81}, -- carpet and both entrance-rug orientations
  house_wall={0}, -- a single, level wall course
  house_counter={5,21,38,39,41,47,50,51,54,57,58,59,60}, -- furniture fallback; complete assets own their matched footprints
  stair_down_w={76,77,92,93}, -- Trainer House descends to the west
  void={16}, -- padding outside the Day Care interior
 },
 assets=assets,planter_spray=false,
 prop_ground=ground,
}}}
