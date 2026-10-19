local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
local P=dofile(dir..'/historic_primitives.lua')
return function(a)
 if a.id~='park_bin'and a.id~='park_gatehouse'then return a end
 a.surfaces={P.s({0,0,1,1},'vertical',0,1)};a.voxelEdits={{x=0,y=0,z=0,remove=true}}
 if a.id=='park_bin'then
  for y=0,12 do for x=1,14 do for z=1,14 do
   local r=(y==12 and 6.8 or y==0 and 5.5 or 6.2)
   local q=(x-7.5)^2+(z-7.5)^2
   if q<=r*r and(y==0 or q>=(r-1.5)^2)then
    -- All donors are metal from inside the native drawing. The lip is
    -- light steel; the interior uses the recessed dark opening texel.
    local i=y==12 and 3*16+7 or z<4 and 5*16+7 or x>10 and 12*16+10 or 10*16+7
    P.put(a,x,y,z,i)
   end
  end end end
 else
  local function mouth(x,y,z)return y<16 and (x==0 or x==1)and z>=64 or y<16 and(z==0 or z==1)and x>=32 and x<64 end
  for y=0,47 do
   for x=0,95 do for _,z in ipairs({0,1,94,95})do if not mouth(x,y,z)then P.put(a,x,y,z,(95-y)*96+x)end end end
   for z=2,93 do for _,x in ipairs({0,1,94,95})do if not mouth(x,y,z)then P.put(a,x,y,z,(95-y)*96+32+z%8)end end end
  end
  -- Native west warp cells are immediately outside the footprint; put
  -- their doorway on that edge, rather than on the south-facing facade.
  P.box(a,4,0,64,1,16,32,function(_,y,z)return(95-y)*96+32+z%8 end)
  P.box(a,32,0,4,32,16,1,function(x,y)return(95-y)*96+x end)
  for z=0,95 do
   local sy=math.floor(z/2);local top=48+math.floor((23.5-math.abs(sy-23.5))*.45)
   P.box(a,0,top,z,96,2,1,function(x)return sy*96+x end)
   for _,x in ipairs({0,1,94,95})do P.box(a,x,48,z,1,top-48,1,48*96+32+z%8)end
  end
 end
 return a
end
