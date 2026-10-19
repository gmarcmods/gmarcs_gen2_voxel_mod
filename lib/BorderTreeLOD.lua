-- The first 32px of filler trees stay voxel accurate. Outer filler rows use
-- 2px voxels, with native source colors, and still occupy every tree position.
local L={}
local trees={park_tree=true,johto_tree=true,johto_small_tree=true,johto_fruit_tree=true,
 modern_tree=true,modern_small_tree=true,forest_tree=true,kanto_tree=true,kanto_sapling=true}
function L.eligible(t)return t.border and trees[t.id]or false end
function L.distant(tx,ty,w,h,tw,th)
 return tx+w<=-4 or ty+h<=-4 or tx>=tw+4 or ty>=th+4
end
function L.model(m)
 local cells,byKey={},{}
 local xmin,xmax=math.floor((m.xmin or 0)/2),math.floor((m.xmax or m.W-1)/2)
 local ymin,ytop=math.floor((m.ymin or 0)/2),math.floor(m.ytop/2)
 local zmin,zmax=math.floor(m.zmin/2),math.floor(m.zmax/2)
 local width,depth=xmax-xmin+1,zmax-zmin+1
 -- Bounded integer keys avoid strings in the emitter's empty-neighbor probes.
 local function key(x,y,z)return ((y-ymin)*depth+z-zmin)*width+x-xmin end
 local function add(x,y,z,i)
  local cx,cy,cz=math.floor(x/2),math.floor(y/2),math.floor(z/2)
  local k=key(cx,cy,cz);local score=x%2+y%2+z%2
  local v=byKey[k]
  if not v then v={x=cx,y=cy,z=cz,i=i,score=score};byKey[k]=v;cells[#cells+1]=v
  elseif score>v.score then v.i,v.score=i,score end
 end
 if m.cells then for _,v in ipairs(m.cells)do add(v.x,v.y,v.z,v.i)end
 else
  for y=m.ymin or 0,m.ytop do for z=m.zmin,m.zmax do for x=m.xmin or 0,m.xmax or m.W-1 do
   local i=m.at(x,y,z);if i then add(x,y,z,i)end
  end end end
 end
 local out={W=math.ceil(m.W/2),xmin=math.floor((m.xmin or 0)/2),xmax=math.floor((m.xmax or m.W-1)/2),
  ymin=math.floor((m.ymin or 0)/2),ytop=math.floor(m.ytop/2),zmin=math.floor(m.zmin/2),zmax=math.floor(m.zmax/2),cells=cells}
 out.at=function(x,y,z)
  if x<xmin or x>xmax or y<ymin or y>ytop or z<zmin or z>zmax then return nil end
  if x%1~=0 or y%1~=0 or z%1~=0 then return nil end
  local v=byKey[key(x,y,z)];return v and v.i
 end
 return out
end
function L.scale(quads)
 for _,q in ipairs(quads)do for i=1,4 do for axis=1,3 do q[i][axis]=q[i][axis]*2 end end end
 return quads
end
return L
