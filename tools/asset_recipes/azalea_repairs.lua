-- Native Kurt workshop furniture and Slowpoke Well; scoped by asset ID.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
local P=dofile(dir..'/historic_primitives.lua')
local tables={traditional_low_table=7,traditional_small_table=7,traditional_side_table=7,traditional_workbench=12,traditional_workbench_side=12}
local cabinets={traditional_double_bookcase=true,traditional_bookcase=true,traditional_cupboard=true,traditional_tall_cabinet=true,traditional_low_cabinet=true,traditional_radio=true}
local function blank(a)a.surfaces={{rect={0,0,1,1},orientation='vertical',height=0,depth=1,z=0}};a.voxelEdits={{x=0,y=0,z=0,remove=true}}end
return function(a)
 local W,H=#a.tiles[1]*8,#a.tiles*8
 if tables[a.id]then
  blank(a);local h=tables[a.id];a.support=h+1
  -- All collision cells carry the top, including the native front band.
  for x=0,W-1 do for z=0,H-1 do for y=h-1,h do
   local sy=math.min(H-9,math.floor(z*(H-8)/H))
   P.put(a,x,y,z,sy*W+x)
  end end end
  for _,xx in ipairs({2,W-5})do for _,zz in ipairs({2,H-5})do P.box(a,xx,0,zz,3,h-1,3,(H-5)*W+xx)end end
  -- Apron and cross braces, with open air beneath the tabletop.
  for x=1,W-2 do for _,z in ipairs({1,H-2})do P.put(a,x,h-2,z,(H-8)*W+x)end end
  if a.id=='traditional_workbench'then
   -- The native hammer, apricorns and vice rise above the work surface.
   P.ellipsoid(a,28,h+3,9,3,2,3,function(x)return 10*W+x end)
   P.box(a,38,h+1,9,2,3,9,12*W+38)
   P.box(a,34,h+4,7,10,3,4,12*W+36)
   P.box(a,51,h+1,8,8,5,6,11*W+53)
   P.box(a,53,h+6,9,4,2,4,10*W+53)
  end
 elseif cabinets[a.id]then
  blank(a);local top=H-5;local depth=a.id=='traditional_radio'and 9 or 12;local back=H-depth
  for x=0,W-1 do for z=back,H-1 do for y=0,top do
   if x<2 or x>=W-2 or z<back+2 or z>=H-2 or y<2 or y>=top-1 then
    local sy=z>=H-2 and math.min(H-1,H-1-y)or math.min(3,y%4)
    P.put(a,x,y,z,sy*W+x)
   end
  end end end
  if a.id=='traditional_radio'then for y=top+1,top+7 do P.put(a,W-3,y,back+1,3*W+W-3)end end
 elseif a.id=='modern_slowpoke_well'then
  blank(a)
  for x=0,W-1 do
   local top=math.floor(18+10*math.sqrt(math.max(0,1-((x-23.5)/24)^2)))
   for z=8,31 do for y=0,top do
    local mouth=x>=16 and x<32 and y<16
    local shell=x<3 or x>=W-3 or z<11 or z>=29 or y>=top-2 or x>=13 and x<16 or x>=32 and x<35
    if not mouth and shell then
     local sy=31-y;local sx=x
     if z<29 then sy=math.min(7,(y+z)%8);sx=x<24 and z%8 or 8+z%8 end
     P.put(a,x,y,z,sy*W+sx)
    end
   end end
  end
  -- Recessed passage, rather than a black slab across the mouth.
  for x=16,31 do for y=0,15 do P.put(a,x,y,9,24*W+16)end end
  for x=16,31 do for z=10,31 do P.put(a,x,0,z,24*W+16)end end
 else return a,false end
 return a,true
end
