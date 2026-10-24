-- Remove isolated voxel specks from one-cell trees and connect their solid
-- trunk/crown pieces with the shortest deterministic Manhattan bridge.
local Surface=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/') or '.')..'/../../lib/AssetSurface.lua')
local targets={johto_small_tree=true,modern_small_tree=true,forest_sapling=true,
 forest_cut_tree=true,kanto_sapling=true}
local function less(a,b)
 if a.y~=b.y then return a.y<b.y end
 if a.z~=b.z then return a.z<b.z end
 return a.x<b.x
end
local function key(c)return c.x..':'..c.y..':'..c.z end
local function components(m)
 local cells={};for _,c in ipairs(m.cells)do cells[#cells+1]=c end
 table.sort(cells,less)
 local byKey={};for _,c in ipairs(cells)do byKey[key(c)]=c end
 local seen,out={},{}
 local ds={{-1,0,0},{0,0,-1},{0,-1,0},{0,1,0},{0,0,1},{1,0,0}}
 for _,first in ipairs(cells)do if not seen[key(first)]then
  local q={first};seen[key(first)]=true;local comp={};local at=1
  while q[at]do local c=q[at];at=at+1;comp[#comp+1]=c
   for _,d in ipairs(ds)do local k=key({x=c.x+d[1],y=c.y+d[2],z=c.z+d[3]})
    if byKey[k]and not seen[k]then seen[k]=true;q[#q+1]=byKey[k]end
   end
  end
  table.sort(comp,less);out[#out+1]=comp
 end end
 table.sort(out,function(a,b)if #a~=#b then return #a>#b end;return less(a[1],b[1])end)
 return out
end
local function nearest(a,b)
 local best,dist
 for _,u in ipairs(a)do for _,v in ipairs(b)do
  local d=math.abs(u.x-v.x)+math.abs(u.y-v.y)+math.abs(u.z-v.z)
  if not dist or d<dist or d==dist and (less(u,best.u)or key(u)==key(best.u)and less(v,best.v))then
   best,dist={u=u,v=v},d
  end
 end end
 return best
end
local function bridge(a,b)
 local pair=nearest(a,b);local u,v=pair.u,pair.v
 local path={{x=u.x,y=u.y,z=u.z,i=u.i,region=u.region}}
 local p={x=u.x,y=u.y,z=u.z}
 for _,axis in ipairs({'x','y','z'})do
  local delta=v[axis]-p[axis];local step=delta<0 and -1 or 1
  for _=1,math.abs(delta)do p[axis]=p[axis]+step
   path[#path+1]={x=p.x,y=p.y,z=p.z,i=u.i,region=u.region}
  end
 end
 return path
end
return function(a)
 if not a or not targets[a.id]then return false end
 local W,H=#a.tiles[1]*8,#a.tiles*8
 local m=Surface.build(W,H,a.surfaces,a.voxelEdits)
 local comps=components(m);local keep={}
 for _,c in ipairs(comps)do if #c>=64 then keep[#keep+1]=c end end
 local edits=a.voxelEdits or {};local overridden={}
 for _,e in ipairs(edits)do overridden[key(e)]=e end
 for _,c in ipairs(comps)do if #c<64 then for _,v in ipairs(c)do
  local k=key(v);if not overridden[k]or not overridden[k].remove then
   local e={x=v.x,y=v.y,z=v.z,remove=true};edits[#edits+1]=e;overridden[k]=e
  end
 end end end
 for n=2,#keep do
  local path=bridge(keep[1],keep[n])
  for i=2,#path-1 do local v=path[i];local k=key(v)
   if not m.at(v.x,v.y,v.z)and (not overridden[k]or overridden[k].remove)then
    local e={x=v.x,y=v.y,z=v.z,i=v.i,region=v.region};edits[#edits+1]=e;overridden[k]=e
   end
  end
  for _,v in ipairs(path)do keep[1][#keep[1]+1]=v end
 end
 a.voxelEdits=edits
 return true
end
