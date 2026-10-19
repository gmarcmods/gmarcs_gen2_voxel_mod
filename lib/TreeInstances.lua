-- Repeated native foliage: immutable local geometry plus streamed visible
-- translations. Terrain mesh handles remain unchanged for companion mods.
local V=...
local Visibility=V.require('MeshVisibility')
local T={enabled=true}
local owners=setmetatable({},{__mode='k'})
local bounds=setmetatable({},{__mode='k'})
function T.available()
 local g=love and love.graphics
 if not(T.enabled and g and g.getSupported and g.drawInstanced and g.newMesh)then return false end
 local ok,s=pcall(g.getSupported)
 return ok and s.instancing==true
end
local function modelBounds(qs,tick)
 local b=bounds[qs];if b then return b end
 b={math.huge,math.huge,math.huge,-math.huge,-math.huge,-math.huge}
 for _,q in ipairs(qs)do if tick then tick()end;for i=1,4 do for a=1,3 do
  b[a]=math.min(b[a],q[i][a]);b[a+3]=math.max(b[a+3],q[i][a])
 end end end
 bounds[qs]=b;return b
end
function T.whole(st,body,bw,bh,masks,tick)
 if st.own then return true end
 local b=modelBounds(st.quads,tick)
 local x0,x1,z0,z1=b[1]+st.mx,b[4]+st.mx,b[3]+st.mz,b[6]+st.mz
 -- Strict interior also excludes zero-area faces on the native boundary.
 if x0>0 and x1<bw and z0>0 and z1<bh then return true end
 if body then return false end
 for _,m in ipairs(masks or {})do
  if x1>=m[1]and x0<=m[3]and z1>=m[2]and z0<=m[4]then return false end
 end
 return true
end
function T.new(format,tick,capacity)
 local byModel,list={},{}
 local c={}
 local transferred=false
 function c:abort()
  if not transferred then for _,m in ipairs(list)do m.mesh:release();m.buffer:release()end;transferred=true end
 end
 function c:add(st,shade)
  local model=byModel[st.quads]
  if model==false then return false end
  if not model then
   local verts,indices={},{}
   for _,q in ipairs(st.quads)do
    tick()
    local shades=shade(q,q.shade)
    local base=#verts
    for i=1,4 do
     local uv=q.uv and q.uv[i]
     verts[#verts+1]={q[i][1],q[i][2],q[i][3],uv and uv[1]or q.u,uv and uv[2]or q.v,
      type(shades)=='table'and shades[i]or shades}
    end
    for _,i in ipairs({1,2,3,1,3,4})do indices[#indices+1]=base+i end
   end
   local mesh,buffer
   local ok=pcall(function()
    mesh=love.graphics.newMesh(format,verts,'triangles','static')
    mesh:setVertexMap(indices)
    buffer=love.graphics.newMesh({{'InstanceOffset','float',3}},math.max(capacity or 1024,1),'points','stream')
    mesh:attachAttribute('InstanceOffset',buffer,'perinstance')
   end)
   if not ok then
    if mesh then pcall(mesh.release,mesh)end
    if buffer then pcall(buffer.release,buffer)end
    byModel[st.quads]=false;return false
   end
   model={mesh=mesh,buffer=buffer,positions={},boxes={},visible={},vertices=#verts}
   byModel[st.quads]=model;list[#list+1]=model
  end
  model.positions[#model.positions+1]={st.mx,0,st.mz}
  local b=modelBounds(st.quads,tick)
  model.boxes[#model.boxes+1]={b[1]+st.mx,b[2],b[3]+st.mz,b[4]+st.mx,b[5],b[6]+st.mz}
  return true
 end
 function c:finish(mesh)
  if mesh then owners[mesh]=list;transferred=true else self:abort()end
 end
 return c
end
function T.has(mesh)
 local list=owners[mesh];return list and #list>0 or false
end
function T.stats(mesh)
 local list=owners[mesh];if not list then return end
 local s={instances=0,modelVertices=0,expandedVertices=0}
 for _,m in ipairs(list)do
  s.instances=s.instances+#m.positions;s.modelVertices=s.modelVertices+m.vertices
  s.expandedVertices=s.expandedVertices+m.vertices*#m.positions
 end
 return s
end
function T.draw(mesh,texture,shader,vp,k,cx,cz)
 local list=owners[mesh];if not list or #list==0 then return 0 end
 local planes=vp and Visibility.planes(vp)
 local count=0
 shader:send('instanced',1)
 for _,m in ipairs(list)do
  local n=0
  for i,p in ipairs(m.positions)do
   if not planes or not Visibility.enabled or Visibility.visiblePrepared(m.boxes[i],planes,k,cx,cz)then
    n=n+1;m.visible[n]=p
   end
  end
  for i=#m.visible,n+1,-1 do m.visible[i]=nil end
  if n>0 then
   m.buffer:setVertices(m.visible)
   if texture then m.mesh:setTexture(texture)end
   love.graphics.drawInstanced(m.mesh,n);count=count+n
  end
 end
 shader:send('instanced',0)
 return count
end
function T.release(mesh)
 local list=owners[mesh];owners[mesh]=nil
 for _,m in ipairs(list or {})do m.mesh:release();m.buffer:release()end
end
return T
