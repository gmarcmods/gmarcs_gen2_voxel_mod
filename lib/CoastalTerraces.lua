-- Explicit Cherrygrove placements; no shared cliff/profile mutation.
local V=...
local C={}
local meshes=setmetatable({},{__mode='k'})
local spec
local last
function C.build(S,map,data,perRow,key)
 if map.id~='CHERRYGROVE_CITY'or not data then return 0 end
 spec=spec or V.data('cherrygrove_terraces')
 local count=0;local quads=meshes[data]
 for _,p in ipairs(spec.placements)do
  local tx,ty=p[1],p[2];local valid=true
  for y=0,3 do for x=0,3 do
   if S.skip[key(tx+x,ty+y)]or map:tileAt(tx+x,ty+y)~=spec.tiles[y+1][x+1]
    or map:isWalkableCell(math.floor((tx+x)/2),math.floor((ty+y)/2))then valid=false end
  end end
  if valid then
   if not quads then
    quads=V.require('TerraceMesh').build(spec,map.tileset.imageWidth or 128,map.tileset.imageHeight or 48,perRow)
    meshes[data]=quads;last={voxels=spec.voxels,quads=#quads,height=spec.height}
   end
   for y=0,3 do for x=0,3 do local k=key(tx+x,ty+y);S.skip[k]=true;S.ground[k]=spec.materials.topTile end end
   S.assetStamps[#S.assetStamps+1]={quads=quads,mx=tx*8,mz=ty*8,own=true}
   count=count+1
  end
 end
 return count
end
function C.stats()return last end
return C
