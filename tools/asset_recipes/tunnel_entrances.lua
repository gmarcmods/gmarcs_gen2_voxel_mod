-- Carve the original rock mouth into an arch with a dark recessed passage.
return function(a)
 if a.id~='johto_cave_mouth'and a.id~='modern_cave_mouth'and a.id~='kanto_cave'then return a end
 a.surfaces={{rect={0,0,1,1},orientation='vertical',height=0,depth=1,z=0}}
 a.voxelEdits={{x=0,y=0,z=0,remove=true}}
 local function put(x,y,z,i)a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=i,region=1}end
 for x=0,15 do
  local edge=math.abs(x-7.5)
  local outer=15-math.max(0,math.floor(edge-5))
  local inner=12-math.max(0,math.floor(edge-2))
  for y=0,outer do for z=0,15 do
   local opening=x>=3 and x<=12 and y<inner
   if not opening then
    local sx=z==15 and x or (x<8 and math.min(2,x)or math.max(13,x))
    put(x,y,z,(15-y)*16+sx)
   elseif z==0 then put(x,y,z,8*16+8)end
  end end
  if x>=3 and x<=12 then for z=1,15 do put(x,0,z,14*16+8)end end
 end
 return a
end
