-- Native Radio Tower equipment and broadcast architecture detail.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
local P=dofile(dir..'/historic_primitives.lua');local M={}
local function reset(a)a.surfaces={{rect={0,0,1,1},orientation='vertical',height=0,depth=1,z=0}};a.voxelEdits={{x=0,y=0,z=0,remove=true}}end
local function tex(a,x,y)return math.max(0,math.min(#a.tiles*8-1,y))*#a.tiles[1]*8+math.max(0,math.min(#a.tiles[1]*8-1,x))end
local function tableShape(a,W,D)
 reset(a);a.support=10
 P.box(a,0,8,0,W,2,D,function(x,_,z)return tex(a,x,math.min(#a.tiles*8-9,z))end)
 for _,x in ipairs({1,W-4})do for _,z in ipairs({1,D-4})do P.box(a,x,0,z,3,8,3,tex(a,x,#a.tiles*8-3))end end
 for x=1,W-2 do P.put(a,x,7,D-2,tex(a,x,#a.tiles*8-3))end
end
local function phone(a,x,z)
 P.box(a,x,10,z,7,3,5,tex(a,x,3))
 P.box(a,x,13,z,2,2,4,tex(a,x,2));P.box(a,x+5,13,z,2,2,4,tex(a,x+5,2))
 P.box(a,x+1,14,z,5,1,2,tex(a,x+1,1))
 for xx=x+2,x+4 do P.put(a,xx,13,z+3,tex(a,xx,5))end
end
function M.repair(a)
 local id=a.id;local W,H=#a.tiles[1]*8,#a.tiles*8
 if id=='radio_office_desk'or id=='radio_document_desk'or id=='radio_studio_table'then
  tableShape(a,W,H)
  if id=='radio_office_desk'then phone(a,16,3)
  elseif id=='radio_document_desk'then
   phone(a,24,3);P.box(a,16,10,5,7,1,7,function(x,_,z)return tex(a,x,z-5)end)
   P.box(a,21,11,5,2,1,2,tex(a,22,1))
  else
   -- A desk microphone on a round foot, capsule and a short boom.
   P.ellipsoid(a,8,10,5,3,1,3,function()return tex(a,8,4)end)
   P.box(a,8,11,5,1,9,1,tex(a,8,4))
   P.ellipsoid(a,8,21,5,3,4,2,function(x,y)return tex(a,x,math.max(0,24-y))end)
   for x=9,16 do P.put(a,x,18+math.floor((x-9)/4),5,tex(a,8,4))end
   P.box(a,17,10,1,13,2,12,tex(a,20,3))
   for x=19,28,3 do for z=4,10,3 do P.put(a,x,12,z,tex(a,x,2))end end
   for x=2,13 do for z=24,36 do P.put(a,x,10,z,tex(a,x,z))end end
   P.box(a,11,11,25,2,1,3,tex(a,11,25))
  end
 elseif id=='radio_pc'or id=='radio_reception_terminal'then
  reset(a);P.box(a,1,0,8,14,6,16,tex(a,4,H-3))
  P.box(a,6,6,12,4,3,4,tex(a,6,H-4))
  for x=1,14 do for y=8,21 do for z=8,19 do
   local rim=x<=2 or x>=13 or y<=9 or y>=20
   if z==8 or rim or z==18 then P.put(a,x,y,z,tex(a,x,math.max(0,21-y)))end
  end end end
  P.box(a,1,6,19,14,1,5,function(x,_,z)return tex(a,x,H-5+math.floor((z-19)/2))end)
  for x=3,12,3 do P.put(a,x,7,21,tex(a,x,H-3))end
 elseif id=='radio_file_cabinet'or id=='radio_storage'then
  reset(a);local top=H-1
  for x=0,15 do for z=16,31 do for y=0,top do
   if x<2 or x>=14 or z==16 or y==0 or y==top then P.put(a,x,y,z,tex(a,x,math.max(0,H-1-y)))end
  end end end
  for x=2,13 do for y=1,top-1 do P.put(a,x,y,30,tex(a,x,H-1-y))end end
  for y=5,top-3,7 do P.box(a,6,y,31,4,1,1,tex(a,6,H-1-y))end
  if id=='radio_file_cabinet'then P.box(a,6,9,31,4,1,1,tex(a,6,12))end
 elseif id=='radio_blue_table'or id=='radio_blue_telephone_table'then
  reset(a)
  P.ellipsoid(a,7.5,8,7.5,7,1,7,function(x,_,z)return tex(a,x,z%8)end)
  P.box(a,6,0,6,4,8,4,tex(a,7,12));P.box(a,3,0,3,10,1,10,tex(a,7,12))
  if id=='radio_blue_telephone_table'then phone(a,8,3)end
 elseif id=='radio_studio_window'or id=='radio_window_partition'or id=='radio_table_window'or id=='radio_upper_window'then
  reset(a);local base=id=='radio_table_window'and 8 or id=='radio_upper_window'and 16 or 0
  for x=0,15 do for sy=0,H-1 do
   local y=base+H-1-sy
   P.put(a,x,y,2,tex(a,x,sy))
   if x<2 or x>=14 or sy<2 or sy>=H-2 or sy==8 then
    P.box(a,x,y,3,1,1,3,tex(a,0,0))
   end
  end end
 elseif id=='radio_wall_notice'then
  reset(a)
  for x=0,15 do for sy=0,15 do local y=23-sy
   P.put(a,x,y,3,tex(a,x,sy));if x==0 or x==15 or sy==0 or sy==15 then P.put(a,x,y,4,tex(a,0,0))end
  end end
 elseif id:match('^radio_reception_top_')then
  reset(a);a.support=9
  for x=0,7 do for z=0,7 do for y=0,8 do
   if y>=7 or z>=6 or x==0 or x==7 then P.put(a,x,y,z,tex(a,x,y>=7 and z or 7-y))end
  end end end
 elseif id=='modern_radio_tower'then
  -- Retain the authored shaft, annex, facade windows, doorway and keep mask.
  local edits={};for _,e in ipairs(a.voxelEdits)do
   local orb=false
   for _,p in ipairs({{16,184},{48,88}})do
    if not e.remove and e.x>=p[1]-8 and e.x<p[1]+8 and e.y>p[2]-8 and e.y<p[2]+8 and e.z>=168 and e.z<=183 then orb=true end
   end
   if not orb then edits[#edits+1]=e end
  end;a.voxelEdits=edits
  local function material(tile,x,y)
   for r,row in ipairs(a.tiles)do for c,t in ipairs(row)do if t==tile then return ((r-1)*8+y%8)*W+(c-1)*8+x%8 end end end
   error('missing radio material '..tile)
  end
  for _,span in ipairs({{0,31,176},{32,63,80}})do local lo,hi,top=unpack(span)
   for y=16,top,32 do for x=lo,hi do if not(x>=16 and x<32 and y<24)then P.put(a,x,y,192,material(33,x,2))end end end
   for _,x in ipairs({lo+2,hi-2})do for y=0,top do if not(x>=16 and x<32 and y<24)then P.put(a,x,y,192,material(29,x,y))end end end
   for x=lo,hi do for z=160,191 do if x==lo or x==hi or z==160 or z==191 then P.box(a,x,top+1,z,1,2,1,material(33,x,z))end end end
  end
  for _,p in ipairs({{16,184},{48,88}})do local cx,cy=p[1],p[2]
   for x=cx-7,cx+7 do for y=cy-7,cy+7 do
    local q=((x-cx)/7.5)^2+((y-cy)/7.5)^2
    if q<=1 then local z=179-math.floor(3*(1-q));P.box(a,x,y,z,1,1,2,tex(a,x-8,191-y))end
   end end
   P.box(a,cx-1,cy-8,172,2,9,2,material(80,1,4))
   for y=cy+8,cy+32 do for _,x in ipairs({cx-3,cx+3})do P.put(a,x,y,174,material(80,1,y));P.put(a,x,y,178,material(80,1,y))end
    local x=cx-3+(y-cy)%7;P.put(a,x,y,174,material(33,1,2))
    if (y-cy)%4==0 then for x=cx-3,cx+3 do P.put(a,x,y,174,material(33,x,2))end end
   end
  end
 else return a,false end
 return a,true
end
function M.extras()
 local list={};for _,t in ipairs({5,6,7,8,9,21,22,23,24,36,64,84,85,90})do
  local a=P.blank('radio_reception_top_'..t,{{t}});M.repair(a);list[#list+1]=a
 end;return list
end
return M
