-- Native CRT fronts on deep housings, open desk legs, and actual room floors.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
local P=dofile(dir..'/historic_primitives.lua');local R={}
local function desk(a,facility)
 local t=a.tiles;local W,H=#t[1]*8,#t*8
 local replacement=P.blank(a.id,t)
 a.surfaces,a.voxelEdits=replacement.surfaces,replacement.voxelEdits
 local function tex(x,y)return math.max(0,math.min(H-1,y))*W+math.max(0,math.min(W-1,x))end
 local wood=facility and tex(8,H-5)or tex(4,4)
 P.box(a,0,7,0,W,2,16,wood)
 for _,x in ipairs({1,W-4})do for _,z in ipairs({1,12})do P.box(a,x,0,z,3,7,3,tex(x,H-3))end end
 local function monitor(x0,sy,w,h,base,z,d)
  -- Only the south face samples the screen. Top/sides sample the bezel,
  -- instead of wrapping repeated screen strips around every depth voxel.
  P.box(a,x0,base,z,w,h,d,function(x,y,zz)
   return zz==z+d-1 and tex(x,sy+h-1-(y-base))or tex(x0,sy)
  end)
  P.box(a,x0+3,9,z+2,math.max(2,w-6),base-9,math.max(2,d-3),tex(x0,sy))
 end
 if facility then
  monitor(1,1,14,9,11,1,8)
  monitor(20,0,11,14,9,0,9)
  P.box(a,2,9,9,12,1,4,function(x,_,z)return tex(x,10+z-9)end)
 else
  monitor(18,6,12,10,11,1,8)
 end
 a.groundTile=facility and 0 or 16
end
function R.apply(p)
 for _,a in ipairs(p.buildings.TILESET_FACILITY)do
  -- The commonest neighboring "flat" tile can be a wooden fixture top.
  -- Tile zero is the native unpatterned floor, also behind these sprites.
  a.groundTile=0
  if a.id=='facility_computer_desk'then desk(a,true)end
 end
 for _,a in ipairs(p.buildings.TILESET_UNDERGROUND)do
  if a.id=='underground_computer_desk'then desk(a,false)end
  if a.id=='underground_stool'then
   a.groundTile=16
   a.surfaces={P.s({2,0,12,8},'horizontal',6,2)};a.voxelEdits={}
   for _,x in ipairs({3,11})do for _,z in ipairs({1,6})do P.box(a,x,0,z,2,6,2,14*16+x)end end
  end
 end
 return p
end
return R
