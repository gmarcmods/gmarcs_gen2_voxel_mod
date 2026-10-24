-- Keep the authored pagoda shape. The roof surface repeats the native tile's
-- dark/grey roofing rows, not its white underside/eave stripe every 8 pixels.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')
local Surface=dofile(dir..'/../../lib/AssetSurface.lua')
local levels={johto_sprout_tower=3,johto_burned_tower=3,johto_tin_tower=9}
return function(a)
 local n=levels[a.id];if not n then return false end
 local W=#a.tiles[1]*8;local origin
 for y,row in ipairs(a.tiles)do for x,tile in ipairs(row)do
  if tile==82 and not origin then origin=(y-1)*8*W+(x-1)*8 end
 end end
 assert(origin,'pagoda lost its native roof tile')
 -- Derive roof courses from the finished authored model. Its storeys are
 -- 24px with two-layer eaves; the older architecture recipe is different.
 local model=Surface.build(W,#a.tiles*8,a.surfaces,a.voxelEdits,false)
 local bounds={}
 for _,e in ipairs(model.cells)do
  local b=bounds[e.y]or{x0=e.x,x1=e.x,z0=e.z,z1=e.z,count=0};bounds[e.y]=b
  b.count=b.count+1
  b.x0,b.x1=math.min(b.x0,e.x),math.max(b.x1,e.x)
  b.z0,b.z1=math.min(b.z0,e.z),math.max(b.z1,e.z)
 end
 local bands=0
 for y,b in pairs(bounds)do
  if b.count<W*8 then bounds[y]=nil else bands=bands+1 end
 end
 assert(bands==n*2,'unexpected pagoda roof layers')
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
