-- Weak mesh metadata: spatial index ranges over the SAME authored vertices.
-- No distance LOD or geometry simplification. Curved-world bounds conservatively
-- include the entire shader displacement, and translated connected maps use
-- their own model-view-projection matrix.
-- LuaJIT already hoists much of the original loop. Prepared planes help
-- interpreted Lua; retain the faster original loop when JIT is enabled.
local M={enabled=true,cacheEnabled=not(jit and jit.status and jit.status()),prepared=not(jit and jit.status and jit.status())}
local ranges=setmetatable({},{__mode='k'})
local cached=setmetatable({},{__mode='k'})
function M.register(mesh,groups)ranges[mesh]=groups;cached[mesh]=nil end
function M.groups(mesh)return ranges[mesh]end

-- Portable path for app versions whose mod sandbox does not expose FFI.
-- Rewrite the existing index table in place; vertex tables stay unchanged.
function M.index(vertices,quads,indices,check)
 local rows,groups={},{}
 for q=0,quads-1 do
  local v=vertices[q*4+1]
  local x,z=math.floor(v[1]/64),math.floor(v[3]/64)
  local row=rows[z];if not row then row={};rows[z]=row end
  local g=row[x]
  if not g then
   g={quads={},bounds={math.huge,math.huge,math.huge,-math.huge,-math.huge,-math.huge}}
   row[x]=g;groups[#groups+1]=g
  end
  g.quads[#g.quads+1]=q
  local b=g.bounds
  for corner=1,4 do
   local c=vertices[q*4+corner]
   for axis=1,3 do
    if c[axis]<b[axis] then b[axis]=c[axis] end
    if c[axis]>b[axis+3] then b[axis+3]=c[axis] end
   end
  end
  if q%4096==0 then check() end
 end
 local offset=0
 for _,g in ipairs(groups)do
  g.first=offset+1;g.count=#g.quads*6
  for _,q in ipairs(g.quads)do
   local v=q*4
   indices[offset+1]=v+1;indices[offset+2]=v+2;indices[offset+3]=v+3
   indices[offset+4]=v+1;indices[offset+5]=v+3;indices[offset+6]=v+4
   offset=offset+6
   if offset%24576==0 then check() end
  end
  g.quads=nil
 end
 return groups
end

function M.planes(m)
 local p={}
 for row=1,3 do for sign=-1,1,2 do
  local i=(row-1)*4
  p[#p+1]=m[13]+sign*m[i+1];p[#p+1]=m[14]+sign*m[i+2]
  p[#p+1]=m[15]+sign*m[i+3];p[#p+1]=m[16]+sign*m[i+4]
 end end
 return p
end
function M.visiblePrepared(b,planes,k,cx,cz)
 local x0,y0,z0,x1,y1,z1=b[1],b[2],b[3],b[4],b[5],b[6]
 if k and k>0 then
  local nearX=math.max(x0-cx,0,cx-x1)
  local nearZ=math.max(z0-cz,0,cz-z1)
  local farX=math.max(math.abs(x0-cx),math.abs(x1-cx))
  local farZ=math.max(math.abs(z0-cz),math.abs(z1-cz))
  y0=y0-k*(farX*farX+farZ*farZ)
  y1=y1-k*(nearX*nearX+nearZ*nearZ)
 end
 for i=1,24,4 do
  local a,bp,c,d=planes[i],planes[i+1],planes[i+2],planes[i+3]
  if a*(a>=0 and x1 or x0)+bp*(bp>=0 and y1 or y0)+c*(c>=0 and z1 or z0)+d < -0.001 then return false end
 end
 return true
end
function M.visible(b,m,k,cx,cz)
 local x0,y0,z0,x1,y1,z1=b[1],b[2],b[3],b[4],b[5],b[6]
 if k and k>0 then
  local nearX=math.max(x0-cx,0,cx-x1)
  local nearZ=math.max(z0-cz,0,cz-z1)
  local farX=math.max(math.abs(x0-cx),math.abs(x1-cx))
  local farZ=math.max(math.abs(z0-cz),math.abs(z1-cz))
  y0=y0-k*(farX*farX+farZ*farZ)
  y1=y1-k*(nearX*nearX+nearZ*nearZ)
 end
 -- Test the farthest AABB corner against each homogeneous clipping plane.
 -- Crossing the near plane (including the camera being inside) stays visible.
 for row=1,3 do
  for sign=-1,1,2 do
   local i=(row-1)*4
   local a,bp,c,d=m[13]+sign*m[i+1],m[14]+sign*m[i+2],m[15]+sign*m[i+3],m[16]+sign*m[i+4]
   if a*(a>=0 and x1 or x0)+bp*(bp>=0 and y1 or y0)+c*(c>=0 and z1 or z0)+d < -0.001 then return false end
  end
 end
 return true
end

local function uncachedDraw(mesh,groups,vp,k,cx,cz)
 local submitted=0
 local planes=M.prepared and M.planes(vp)
 -- Coalesce adjacent visible ranges to avoid a draw call for every region.
 local first,count
 local function flush()
  if first then mesh:setDrawRange(first,count);love.graphics.draw(mesh);submitted=submitted+count end
 end
 for _,g in ipairs(groups)do
  local visible=planes and M.visiblePrepared(g.bounds,planes,k,cx,cz)
  if not planes then visible=M.visible(g.bounds,vp,k,cx,cz)end
  if visible then
   if first then count=count+g.count else first,count=g.first,g.count end
  else flush();first,count=nil,nil end
 end
 flush();mesh:setDrawRange()
 return submitted
end

function M.draw(mesh,vp,k,cx,cz)
 local groups=ranges[mesh]
 if not groups then love.graphics.draw(mesh);return end
 if not M.enabled then
  love.graphics.draw(mesh)
  local n=0;for _,g in ipairs(groups)do n=n+g.count end
  return n
 end
 if not M.cacheEnabled then return uncachedDraw(mesh,groups,vp,k,cx,cz)end
 -- Retain the last camera/light results. Compare values: callers frequently
 -- allocate matrices anew or mutate the same table in place. Two entries avoid
 -- the ordinary main/shadow passes evicting each other every frame.
 local entries=M.cacheEnabled and cached[mesh]
 local hit
 if entries then
  for _,entry in ipairs(entries)do
   if entry.k==k and entry.cx==cx and entry.cz==cz then
    local same=true
    for i=1,16 do if entry.vp[i]~=vp[i]then same=false;break end end
    if same then hit=entry;break end
   end
  end
 end
 if not hit then
  local planes=M.prepared and M.planes(vp)
  entries=entries or {}
  hit=entries[2]or{vp={},runs={}}
  hit.k,hit.cx,hit.cz,hit.count=k,cx,cz,0
  for i=1,16 do hit.vp[i]=vp[i]end
  local used=0
  local first,count
  local function flush()
   if first then
    used=used+2;hit.runs[used-1]=first;hit.runs[used]=count;hit.count=hit.count+count
   end
  end
  for _,g in ipairs(groups)do
   local visible=planes and M.visiblePrepared(g.bounds,planes,k,cx,cz)
   if not planes then visible=M.visible(g.bounds,vp,k,cx,cz)end
   if visible then
    if first then count=count+g.count else first,count=g.first,g.count end
   else flush();first,count=nil,nil end
  end
  flush()
  for i=#hit.runs,used+1,-1 do hit.runs[i]=nil end
  if M.cacheEnabled then
   cached[mesh]=entries
   entries[2]=entries[1];entries[1]=hit
  end
 end
 for i=1,#hit.runs,2 do
  mesh:setDrawRange(hit.runs[i],hit.runs[i+1]);love.graphics.draw(mesh)
 end
 mesh:setDrawRange()
 return hit.count
end
return M
