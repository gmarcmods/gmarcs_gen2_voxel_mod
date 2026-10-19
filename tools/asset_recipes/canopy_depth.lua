-- Extend only foliage along the tree's own native footprint. Keep its
-- original texels, height, trunk, width and placement/collision unchanged.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.'
local Surface=dofile(dir..'/../../lib/AssetSurface.lua')
return function(a,leafRows,oldMin,oldMax,newMin,newMax)
 local W,H=#a.tiles[1]*8,#a.tiles*8
 local m=Surface.build(W,H,a.surfaces,a.voxelEdits)
 local edits={{x=0,y=0,z=0,remove=true}}
 local oldD,newD=oldMax-oldMin+1,newMax-newMin+1
 for _,c in ipairs(m.cells) do
  local z0,z1=c.z,c.z
  if math.floor(c.i/W)<leafRows and c.z>=oldMin and c.z<=oldMax then
   z0=newMin+math.floor((c.z-oldMin)*newD/oldD)
   z1=newMin+math.floor((c.z-oldMin+1)*newD/oldD)-1
  end
  for z=z0,z1 do edits[#edits+1]={x=c.x,y=c.y,z=z,i=c.i,region=1} end
 end
 a.surfaces={{rect={0,0,1,1},orientation='vertical',height=0,depth=1,z=0}}
 a.voxelEdits=edits
end
