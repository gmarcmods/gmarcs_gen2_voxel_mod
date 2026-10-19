-- The native left-facing Persian on its southern pedestal/hitbox cell.
-- Keep all surface colors sourced from the selected original 16x32 sprite.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
local P=dofile(dir..'/historic_primitives.lua');local R={}
function R.repair(a)
 if a.id~='underground_statue'then return false end
 a.surfaces={P.s({0,0,1,1},'vertical',0,1,16)}
 a.voxelEdits={{x=0,y=0,z=16,remove=true}}
 local function sample(x,y,z)return (31-y)*16+math.max(0,math.min(15,x))end
 -- Square stone pedestal with a recessed shaft and bevelled foot/cap.
 for y=0,15 do local inset=(y<2 or y>=14)and 0 or 2
  P.box(a,inset,y,16+inset,16-2*inset,1,16-2*inset,sample)
 end
 -- Trace the native statue's silhouette and retain every visible texel.
 -- This is the original side profile, not a newly designed animal.
 local outline={
  '...##...........',
  '..########..##..',
  '.##########.###.',
  '###########..##.',
  '############.##.',
  '.###########.##.',
  '..###########.#.',
  '...##########.#.',
  '....###########.',
  '....##########..',
  '....##########..',
  '....##########..',
  '....##########..',
  '...###########..',
  '..############..',
  '..###########...',
 }
 local function inside(x,y)
  return x>=0 and x<16 and y>=0 and y<16 and outline[y+1]:sub(x+1,x+1)=='#'
 end
 -- Distance from the traced boundary makes a rounded back to the volume:
 -- narrow ears/tail, thicker neck and chest. The continuous south-facing surface
 -- always carries that pixel of the original picture, including its eyes,
 -- shading and outline. No flat yellow recoloring.
 for sy=0,15 do for x=0,15 do if inside(x,sy)then
  local radius=3
  for dy=-3,3 do for dx=-3,3 do
   if not inside(x+dx,sy+dy)then radius=math.min(radius,math.max(math.abs(dx),math.abs(dy)))end
  end end
  local half=math.max(1,radius)
  for z=24-half,28 do P.put(a,x,31-sy,z,sy*16+x)end
 end end end
 return true
end
function R.apply(p)
 for _,a in ipairs(p.buildings.TILESET_UNDERGROUND)do R.repair(a)end
 return p
end
return R
