-- Small native cuttable models stay outside the static terrain upload.
-- Their visibility reads current collision, including the cart's regrowth.
local V=...;local P={};local plans={};local previous={}
local function cut(map,x,y)
 if x<0 or y<0 or x>=map.widthCells or y>=map.heightCells then return false end
 local c=map:cellCollision(x,y);return c==0x12 or c==0x1a
end
function P.prepare(S,map)
 if not(map.tileset and map.tileset.generation==2 and map.cellCollision)then return end
 local field=require('src.world.gen2.FieldMoves')
 if not field.CUT_BLOCKS[map.tileset.id]then return end
 local targets={};local list={}
 for y=0,map.heightCells-1 do for x=0,map.widthCells-1 do if cut(map,x,y)then
  local p={x=x,y=y,bx=math.floor(x/2),by=math.floor(y/2),stamps={}}
  p.block=map:blockAt(p.bx,p.by);targets[y*1024+x]=p;list[#list+1]=p
 end end end
 local function target(q,mx,mz)
  local x,z=0,0;for i=1,4 do x=x+q[i][1];z=z+q[i][3]end
  return targets[math.floor((z/4+(mz or 0))/16)*1024+math.floor((x/4+(mx or 0))/16)]
 end
 for _,stamps in ipairs({S.assetStamps or{},S.roundStamps or{}})do for _,stamp in ipairs(stamps)do
  local owner
  for _,q in ipairs(stamp.quads)do owner=target(q,stamp.mx,stamp.mz);if owner then break end end
  if owner then stamp.liveCut=true;owner.stamps[#owner.stamps+1]=stamp end
 end end
 -- Non-instanced generated props use world-space quads.
 for _,q in ipairs(S.objectQuads or{})do
  local owner=target(q)
  if owner then
   q.liveCut=true
   owner.raw=owner.raw or {quads={},mx=0,mz=0}
   owner.raw.quads[#owner.raw.quads+1]=q
  end
 end
 for _,p in ipairs(list)do if p.raw then p.stamps[#p.stamps+1]=p.raw;p.raw=nil end end
 P.invalidate(map.id)
 plans[map.id]={targets=list,tileset=map.tileset.id}
end
function P.visible(map)
 local count=0;local plan=plans[map.id]
 for _,p in ipairs(plan and plan.targets or{})do
  if #p.stamps>0 and cut(map,p.x,p.y)then count=count+1 end
 end
 return count
end
function P.handles(mapId,bx,by,block)
 local plan=plans[mapId];if not plan then return false end
 local field=require('src.world.gen2.FieldMoves')
 for _,p in ipairs(plan.targets)do if p.bx==bx and p.by==by and #p.stamps>0 then
  local replacement=field.blockReplacement(field.CUT_BLOCKS,plan.tileset,p.block)
  if block==replacement or block==p.block then return true end
 end end
 return false
end
local function mesh(stamp)
 if stamp.liveMesh then return stamp.liveMesh end
 local vertices,indices={},{}
 for _,q in ipairs(stamp.quads)do
  local first=#vertices
  for i=1,4 do local c=q[i];local uv=q.uv and q.uv[i]or{q.u,q.v}
   local shade=type(q.shade)=='table'and q.shade[i]or q.shade
   -- Same contact attenuation as ChunkMesher.groundShades.
   shade=shade*(c[2]>=6 and 1 or 1-.288*(1-c[2]/6))
   vertices[#vertices+1]={c[1],c[2],c[3],uv[1],uv[2],shade}
  end
  for _,i in ipairs({1,2,3,1,3,4})do indices[#indices+1]=first+i end
 end
 stamp.liveMesh=V.require('Voxel3D').newMesh(vertices,indices);return stamp.liveMesh
end
function P.draw(map,texture,ox,oz,shadow)
 local plan=plans[map.id];if not plan then return end
 local R=shadow or V.require('Voxel3D');local M=V.require('Mat4')
 for _,p in ipairs(plan.targets)do if cut(map,p.x,p.y)then
  for _,stamp in ipairs(p.stamps)do
   R.draw(mesh(stamp),texture,M.translate((ox or 0)+stamp.mx,0,(oz or 0)+stamp.mz))
  end
 end end
end
function P.invalidate(id)
 for key,plan in pairs(plans)do if not id or key==id then
  for _,p in ipairs(plan.targets)do for _,stamp in ipairs(p.stamps)do
   if stamp.liveMesh then stamp.liveMesh:release();stamp.liveMesh=nil end
  end end
  plans[key]=nil
 end end
end
function P.setLive(live)
 for id in pairs(plans)do if not live[id]and not previous[id]then P.invalidate(id)end end
 previous=live
end
return P
