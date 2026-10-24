-- Keep the authored pagoda shape. The roof surface repeats the native tile's
-- dark/grey roofing rows, not its white underside/eave stripe every 8 pixels.
local levels={johto_sprout_tower=3,johto_burned_tower=3,johto_tin_tower=9}
return function(a)
 local n=levels[a.id];if not n then return false end
 local W=#a.tiles[1]*8;local origin
 for y,row in ipairs(a.tiles)do for x,tile in ipairs(row)do
  if tile==82 and not origin then origin=(y-1)*8*W+(x-1)*8 end
 end end
 assert(origin,'pagoda lost its native roof tile')
 local bounds={}
 for _,e in ipairs(a.voxelEdits)do
  if not e.remove and e.y<n*28 and e.y%28>=24 then
   local b=bounds[e.y]or{x0=e.x,x1=e.x,z0=e.z,z1=e.z};bounds[e.y]=b
   b.x0,b.x1=math.min(b.x0,e.x),math.max(b.x1,e.x)
   b.z0,b.z1=math.min(b.z0,e.z),math.max(b.z1,e.z)
  end
 end
 for _,e in ipairs(a.voxelEdits)do
  local b=bounds[e.y]
  if b and not e.remove then
   local edge=e.x==b.x0 or e.x==b.x1 or e.z==b.z0 or e.z==b.z1
   local row=(edge or e.z%4==0)and 0 or 1
   e.i=origin+row*W+e.x%8
  end
 end
 return true
end
