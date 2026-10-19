-- Match the native 6x6-cell gate footprint, including its two warp approaches.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
local P=dofile(dir..'/historic_primitives.lua')
return function(a)
 if a.id~='forest_gate_north'and a.id~='forest_gate_south'then return a end
 local north=a.id=='forest_gate_north'
 a.surfaces={{rect={0,0,1,1},orientation='vertical',height=0,depth=1,z=0}}
 a.voxelEdits={{x=0,y=0,z=0,remove=true}}
 local function mouth(x,y,z)
  return y<16 and(north and x>=16 and x<32 and z>=80 or not north and x<16 and z>=64)
 end
 for y=0,47 do
  local sy=95-y
  for x=0,95 do for _,z in ipairs({0,1,94,95})do if not mouth(x,y,z)then
   local sx=z>=94 and x or 32+x%8
   P.put(a,x,y,z,sy*96+sx)
  end end end
  for z=2,93 do for _,x in ipairs({0,1,94,95})do if not mouth(x,y,z)then
   P.put(a,x,y,z,sy*96+32+z%8)
  end end end
 end
 -- Keep the entry cell hollow; the door is one full cell behind the hull.
 if north then
  for x=16,31 do for y=0,15 do P.put(a,x,y,79,(95-y)*96+x)end end
  for z=80,93 do for y=0,15 do for _,x in ipairs({15,32})do P.put(a,x,y,z,(95-y)*96+x)end end end
 else
  for z=64,95 do for y=0,15 do P.put(a,16,y,z,80*96+16)end end
  for x=2,15 do for y=0,15 do P.put(a,x,y,63,(95-y)*96+32+x%8)end end
 end
 -- Stretch the roof drawing over the whole blocked footprint, retaining
 -- its pitched silhouette while sharing two depth rows per source row.
 for z=0,95 do
  local sy=math.floor(z/2)
  local top=48+math.floor((23.5-math.abs(sy-23.5))*.45)
  for x=0,95 do for y=top,top+1 do P.put(a,x,y,z,sy*96+x)end end
  for _,x in ipairs({0,1,94,95})do for y=48,top-1 do P.put(a,x,y,z,48*96+32+z%8)end end
 end
 return a
end
