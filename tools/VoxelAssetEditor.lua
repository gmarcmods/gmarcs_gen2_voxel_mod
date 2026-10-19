-- Sprite-region authoring. The preview and game use the same voxel builder.
local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/tools/') or '.'
local Surface=dofile(root..'/lib/AssetSurface.lua')
local E={}; E.__index=E
local function copy(t)
  if type(t)~='table' then return t end
  local r={}; for k,v in pairs(t) do r[k]=copy(v) end; return r
end
local function inside(mx,my,r) return mx>=r.x and my>=r.y and mx<r.x+r.w and my<r.y+r.h end
function E.new(model,tset,tiles,existing)
  local W,H=#tiles[1]*8,#tiles*8
  return setmetatable({model=model,tset=tset,tiles=copy(tiles),original=copy(existing),W=W,H=H,
    nameState={text=existing and existing.id or '',focused=true},
    surfaces=copy(existing and existing.surfaces or {{rect={0,0,W,H},orientation='vertical',depth=1,height=0,z=0}}),
    voxelEdits=copy(existing and existing.voxelEdits or {}),
    tool='brush',brushSize=1,voxelSelection={},selectionShape='box',
    selected=1,yaw=.55,pitch=.45,zoom=1,panX=0,panY=0,history={},future={},dirty=true,revision=0},E)
end
function E:snapshot()
  return {surfaces=copy(self.surfaces),voxelEdits=copy(self.voxelEdits)}
end
function E:restore(state)
  self.voxelSelection={}
  self.surfaces=state.surfaces; self.voxelEdits=state.voxelEdits; self.dirty=true
  self.revision=self.revision+1
end
function E:checkpoint()
  self.history[#self.history+1]=self:snapshot(); self.future={}; self.dirty=true
  self.revision=self.revision+1
end
function E:undo()
  if #self.history==0 then return end
  self.future[#self.future+1]=self:snapshot(); self:restore(table.remove(self.history))
end
function E:redo()
  if #self.future==0 then return end
  self.history[#self.history+1]=self:snapshot(); self:restore(table.remove(self.future))
end
function E:assign(orientation)
  self:checkpoint()
  if self.selection then
    local height=math.max(0,self.H-self.selection[2]-self.selection[4])
    self.surfaces[#self.surfaces+1]={rect=copy(self.selection),orientation=orientation,depth=1,height=height,z=0}
    self.selected=#self.surfaces; self.selection=nil
  elseif self.surfaces[self.selected] then self.surfaces[self.selected].orientation=orientation end
end
function E:document(id)
  local spec=copy(self.original or {})
  spec.id=id; spec.tiles=copy(self.tiles); spec.surfaces=copy(self.surfaces); spec.tileShapes=nil
  spec.voxelEdits=#self.voxelEdits>0 and copy(self.voxelEdits) or nil
  return spec
end
function E:previewProfile()
  local profile=self.model:fuse()
  profile.buildings=profile.buildings or {}
  local id=self.original and self.original.id or '__editor_preview__'
  local list={self:document(id)}
  for _,asset in ipairs(profile.buildings[self.tset] or {}) do
    if asset.id~=id then list[#list+1]=asset end
  end
  profile.buildings[self.tset]=list
  return profile
end
function E:save(applied,close)
  local id=self.nameState.text:match('^%s*(.-)%s*$')
  if id=='' then self.error='Enter an asset name'; return false end
  for _,asset in ipairs((self.model:fuse().buildings or {})[self.tset] or {}) do
    if asset.id==id and (not self.original or asset.id~=self.original.id) then self.error='That name already exists'; return false end
  end
  if #self.surfaces==0 then self.error='Add a surface before saving'; return false end
  local spec=self:document(id)
  self.model:push({op='building',tset=self.tset,id=self.original and self.original.id or id,spec=spec})
  if applied then applied(id) end
  if close then close() end
  return true
end

-- Each exposed voxel face samples its source texel. No debug-color geometry.
local faceDefs={
  {1,0,0, .78, {{1,0,0},{1,1,0},{1,1,1},{1,0,1}}},
  {-1,0,0,.78, {{0,0,1},{0,1,1},{0,1,0},{0,0,0}}},
  {0,1,0,1, {{0,1,0},{0,1,1},{1,1,1},{1,1,0}}},
  {0,-1,0,.55,{{0,0,1},{0,0,0},{1,0,0},{1,0,1}}},
  {0,0,1,.92,{{1,0,1},{1,1,1},{0,1,1},{0,0,1}}},
  {0,0,-1,.92,{{0,0,0},{0,1,0},{1,1,0},{1,0,0}}},
}
function E:geometry()
  if not self.dirty and self.faces then return end
  local m=Surface.build(self.W,self.H,self.surfaces,self.voxelEdits)
  self.voxels=m
  -- Sculpting must not recenter the camera underneath the cursor.
  self.viewCenter=self.viewCenter or {(m.xmin+m.xmax+1)/2,(m.ymin+m.ytop+1)/2,(m.zmin+m.zmax+1)/2}
  self.viewSize=self.viewSize or {math.max(1,m.xmax-m.xmin+1),math.max(1,m.ytop-m.ymin+1),math.max(1,m.zmax-m.zmin+1)}
  self.faces={}; self.height=math.max(1,m.ytop+1); self.depth=math.max(1,m.zmax+1)
  for _,c in ipairs(m.cells) do
    for _,f in ipairs(faceDefs) do
      if m.at(c.x+f[1],c.y+f[2],c.z+f[3])==nil then
        local points={}
        for _,p in ipairs(f[5]) do points[#points+1]={c.x+p[1],c.y+p[2],c.z+p[3]} end
        self.faces[#self.faces+1]={points=points,i=c.i,region=c.region,shade=f[4],
          x=c.x,y=c.y,z=c.z,normal={f[1],f[2],f[3]}}
      end
    end
  end
  self.dirty=false
end
local function faceKey(f) return f.x..':'..f.y..':'..f.z end
function E:brushFaces(face)
  if not face then return {} end
  self:geometry()
  local lo=-math.floor((self.brushSize-1)/2); local hi=lo+self.brushSize-1
  local result={}
  for _,f in ipairs(self.faces) do
    local valid=true
    for axis,key in ipairs({'x','y','z'}) do
      local d=f[key]-face[key]
      if f.normal[axis]~=face.normal[axis] or (face.normal[axis]~=0 and d~=0)
        or (face.normal[axis]==0 and (d<lo or d>hi)) then valid=false end
    end
    if valid then result[#result+1]=f end
  end
  return result
end
function E:sculpt(face,pull)
  self:geometry()
  local targets=self.tool=='select' and self.voxelSelection or self:brushFaces(face)
  local edits,seen={},{}
  for _,f in ipairs(targets) do
    local x,y,z=f.x,f.y,f.z
    if pull then x=x+f.normal[1]; y=y+f.normal[2]; z=z+f.normal[3] end
    local key=x..':'..y..':'..z
    if x < -128 or y < -128 or z < -128 or x > 383 or y > 383 or z > 383 then
      self.error='Voxel limit reached'; return false
    end
    if not seen[key] and self.voxels.at(f.x,f.y,f.z)~=nil and
      (not pull or self.voxels.at(x,y,z)==nil) then
      seen[key]=true
      edits[#edits+1]={x=x,y=y,z=z,remove=not pull or nil,i=pull and f.i or nil,region=f.region}
    end
  end
  if #edits==0 then return false end
  self:checkpoint()
  for _,edit in ipairs(edits) do self.voxelEdits[#self.voxelEdits+1]=edit end
  self.voxelSelection={}
  self.selected=face and face.region or self.selected; self.selection=nil; self.error=nil
  return true
end
local function contains(poly,x,y)
  local hit=false; local j=#poly-1
  for i=1,#poly,2 do
    if (poly[i+1]>y)~=(poly[j+1]>y) and x<(poly[j]-poly[i])*(y-poly[i+1])/(poly[j+1]-poly[i+1])+poly[i] then hit=not hit end
    j=i
  end
  return hit
end
function E:viewport(ui,r)
  local G=love.graphics
  G.setColor(.15,.17,.20); G.rectangle('fill',r.x,r.y,r.w,r.h)
  self:geometry()
  local hover=inside(ui.mx,ui.my,r)
  if hover and ui.scrollDy~=0 then self.zoom=math.max(.25,math.min(5,self.zoom*1.12^ui.scrollDy)) end
  local shift=love.keyboard.isDown and love.keyboard.isDown('lshift','rshift')
  local middle=love.mouse.isDown(3)
  local alt=love.keyboard.isDown and love.keyboard.isDown('lalt','ralt')
  local cameraDrag=middle or (alt and love.mouse.isDown(1))
  local orbit=cameraDrag and not shift; local pan=cameraDrag and shift
  if hover and (orbit or pan) then
    if self.drag then
      local dx,dy=ui.mx-self.drag[1],ui.my-self.drag[2]
      if pan then self.panX=self.panX+dx; self.panY=self.panY+dy
      else self.yaw=self.yaw+dx*.01; self.pitch=math.max(-1.3,math.min(1.3,self.pitch+dy*.01)) end
    end
    self.drag={ui.mx,ui.my}
  else self.drag=nil end
  self.fitScale=self.fitScale or math.min(r.w/(self.viewSize[1]+self.viewSize[3]+6),r.h/(self.viewSize[2]+self.viewSize[3]+6))
  local scale=self.fitScale*self.zoom
  local co,si,cp,sp=math.cos(self.yaw),math.sin(self.yaw),math.cos(self.pitch),math.sin(self.pitch)
  local function project(p)
    local x,y,z=p[1]-self.viewCenter[1],p[2]-self.viewCenter[2],p[3]-self.viewCenter[3]
    local a,b=x*co-z*si,x*si+z*co
    return r.x+r.w/2+self.panX+a*scale,r.y+r.h/2+self.panY+(b*sp-y*cp)*scale,b*cp+y*sp
  end
  G.setScissor(r.x,r.y,r.w,r.h)
  G.setColor(.26,.29,.33)
  for n=0,math.max(self.W,self.depth),2 do
    local a,b=project({n,0,0}); local c,d=project({n,0,self.depth}); G.line(a,b,c,d)
    a,b=project({0,0,n}); c,d=project({self.W,0,n}); G.line(a,b,c,d)
  end
  local cacheKey=table.concat({r.x,r.y,r.w,r.h,scale,self.yaw,self.pitch,self.panX,self.panY},':')
  local cache=self.renderCache
  if not cache or cache.key~=cacheKey or cache.geometry~=self.faces or cache.atlas~=self.atlas then
    if cache and cache.mesh then cache.mesh:release() end
    local faces={}
    for _,f in ipairs(self.faces) do
      local n=f.normal
      if n[1]*si*cp+n[2]*sp+n[3]*co*cp>0.00001 then
      local poly,depth={},0
      for _,p in ipairs(f.points) do local x,y,z=project(p); poly[#poly+1]=x; poly[#poly+1]=y; depth=depth+z end
      faces[#faces+1]={poly=poly,depth=depth/4,source=f}
      end
    end
    table.sort(faces,function(a,b) return a.depth<b.depth end)
    local aw,ah
    if self.atlas then aw,ah=self.atlas:getDimensions() end
    local vertices={}
    for _,f in ipairs(faces) do
      local src=f.source; local sx,sy=src.i%self.W,math.floor(src.i/self.W)
      if aw then
        local tile=self.tiles[math.floor(sy/8)+1][math.floor(sx/8)+1]
        local perRow=math.floor(aw/8)
        local u=((tile%perRow)*8+sx%8+.5)/aw
        local v=(math.floor(tile/perRow)*8+sy%8+.5)/ah
        for _,k in ipairs({1,2,3,1,3,4}) do vertices[#vertices+1]={f.poly[k*2-1],f.poly[k*2],u,v,src.shade,src.shade,src.shade,1} end
      end
    end
    local mesh
    if #vertices>0 then
      mesh=G.newMesh(vertices,'triangles','static'); mesh:setTexture(self.atlas)
    end
    cache={key=cacheKey,geometry=self.faces,atlas=self.atlas,faces=faces,mesh=mesh}
    self.renderCache=cache
  end
  local faces=cache.faces
  if cache.mesh then G.setColor(1,1,1); G.draw(cache.mesh) end
  local hit
  if hover then
    for j=#faces,1,-1 do
      if contains(faces[j].poly,ui.mx,ui.my) then hit=faces[j];break end
    end
  end
  self.hoverFace=hit and hit.source or nil
  if self.tool=='select' and hover and ui.clicked and not cameraDrag and not alt then
    self.boxDrag={ui.mx,ui.my}; self.boxBase=shift and copy(self.voxelSelection) or {}
    self.nameState.focused=false
  end
  if self.boxDrag then
    local x,y=self.boxDrag[1],self.boxDrag[2]
    local x1,y1,x2,y2=math.min(x,ui.mx),math.min(y,ui.my),math.max(x,ui.mx),math.max(y,ui.my)
    self.voxelSelection=copy(self.boxBase); local seen={}
    for _,f in ipairs(self.voxelSelection) do seen[faceKey(f)]=true end
    local function add(f) if f and not seen[faceKey(f)] then seen[faceKey(f)]=true; self.voxelSelection[#self.voxelSelection+1]=f end end
    if x2-x1<4 and y2-y1<4 then add(hit and hit.source)
    elseif self.selectionShape=='line' then
      -- Sample the rendered line at subpixel intervals and use the same
      -- frontmost-face picking as the cursor, never selecting through geometry.
      local dx,dy=ui.mx-x,ui.my-y
      local steps=math.max(1,math.ceil(math.sqrt(dx*dx+dy*dy)*2))
      for step=0,steps do
        local px,py=x+dx*step/steps,y+dy*step/steps
        if inside(px,py,r) then
          for j=#faces,1,-1 do
            if contains(faces[j].poly,px,py) then add(faces[j].source);break end
          end
        end
      end
    else
      for index,f in ipairs(faces) do
        local cx,cy=0,0
        for k=1,8,2 do cx=cx+f.poly[k]/4; cy=cy+f.poly[k+1]/4 end
        if cx>=x1 and cx<=x2 and cy>=y1 and cy<=y2 then
          local visible=true
          for j=index+1,#faces do if contains(faces[j].poly,cx,cy) then visible=false; break end end
          if visible then add(f.source) end
        end
      end
    end
    G.setColor(.2,.85,1,1)
    if self.selectionShape=='line' then G.line(x,y,ui.mx,ui.my)
    else G.rectangle('line',x1,y1,x2-x1,y2-y1) end
    if not ui.mouseDown then self.boxDrag=nil end
  end
  local highlighted={}
  local targets=self.tool=='select' and self.voxelSelection or self:brushFaces(hit and hit.source)
  for _,f in ipairs(targets) do highlighted[faceKey(f)]=true end
  for _,f in ipairs(faces) do
    if highlighted[faceKey(f.source)] then
      G.setColor(.2,.85,1,.3); G.polygon('fill',f.poly)
      G.setColor(.2,.85,1,.8); G.polygon('line',f.poly)
    end
  end
  if hit then
    G.setColor(shift and .2 or 1,shift and 1 or .65,.25,.35)
    G.polygon('fill',hit.poly)
    G.setColor(shift and .2 or 1,shift and 1 or .65,.25,1)
    G.polygon('line',hit.poly)
    if ui.clicked and not alt and not cameraDrag and self.tool=='brush' then
      self.nameState.focused=false
      if love.keyboard.setTextInput then love.keyboard.setTextInput(false) end
      self:sculpt(hit.source,true)
    end
  end
  if hover and ui.rightClicked and not cameraDrag then
    self.nameState.focused=false
    if love.keyboard.setTextInput then love.keyboard.setTextInput(false) end
    self:sculpt(hit and hit.source,shift)
  end
  G.setScissor()
  G.setColor(.8,.84,.9); G.print(self.tool=='brush' and 'Left: add  |  Right: remove  |  Wheel: zoom'
    or 'Right: push selection  |  Shift + right: pull',r.x+8,r.y+8)
  G.print('Orbit: Alt + left / middle  |  Pan: add Shift',r.x+8,r.y+26)
  G.print(self.tool=='select' and ((self.selectionShape=='line' and 'Line' or 'Box')..': drag visible voxels | Shift: add | '..#self.voxelSelection..' selected')
    or ('Brush: '..self.brushSize..' x '..self.brushSize..' voxels'),r.x+8,r.y+44)
end

function E:draw(ui,model,applied,close)
  local G=love.graphics
  local sw,sh=ui:modalOverlay(); G.push('all'); G.origin(); G.setShader(); G.setScissor()
  G.setColor(.075,.085,.105); G.rectangle('fill',8,8,sw-16,sh-16)
  self.nameState=ui:textInput('Asset name',24,16,math.max(160,sw-240),self.nameState)
  ui._textInputState=self.nameState
  if ui:button('BACK',sw-192,34,76,24) then G.pop(); close(); return end
  if ui:button('SAVE',sw-106,34,76,24) then self:save(applied,close) end
  local left=math.min(300,math.floor(sw*.32)); local sy=100
  local ss=math.max(1,math.floor(math.min((left-32)/self.W,math.min(230,sh*.32)/self.H)))
  local sr={x=24,y=sy,w=self.W*ss,h=self.H*ss}
  G.setColor(.8,.85,.92); G.print('SOURCE • drag a pixel region',24,78)
  if self.atlas then
    local aw,ah=self.atlas:getDimensions(); local perRow=math.floor(aw/8)
    G.setColor(1,1,1)
    for r,row in ipairs(self.tiles) do for c,tile in ipairs(row) do
      local q=G.newQuad(tile%perRow*8,math.floor(tile/perRow)*8,8,8,aw,ah)
      G.draw(self.atlas,q,sr.x+(c-1)*8*ss,sr.y+(r-1)*8*ss,0,ss,ss); q:release()
    end end
  else G.setColor(1,.6,.3); G.print('Source art could not be loaded',24,110) end
  local function pixel() return math.max(0,math.min(self.W-1,math.floor((ui.mx-sr.x)/ss))),math.max(0,math.min(self.H-1,math.floor((ui.my-sr.y)/ss))) end
  if ui.clicked and inside(ui.mx,ui.my,sr) then local x,y=pixel(); self.sourceDrag={x,y} end
  if self.sourceDrag and ui.mouseDown then
    local x,y=pixel(); local a,b=self.sourceDrag[1],self.sourceDrag[2]
    self.selection={math.min(a,x),math.min(b,y),math.abs(x-a)+1,math.abs(y-b)+1}
  elseif not ui.mouseDown then self.sourceDrag=nil end
  local selected=self.surfaces[self.selected]
  local rect=self.selection or selected and selected.rect
  if rect then G.setColor(1,.7,.15); G.rectangle('line',sr.x+rect[1]*ss,sr.y+rect[2]*ss,rect[3]*ss,rect[4]*ss) end
  local y=sy+sr.h+16
  if ui:button('Vertical',24,y,106,24) then self:assign('vertical') end
  if ui:button('Horizontal',138,y,112,24) then self:assign('horizontal') end
  y=y+34
  G.setColor(.75,.8,.86); G.print(self.selection and 'New region selected' or 'Selected surface',24,y)
  y=y+22; selected=self.surfaces[self.selected]
  if selected then
    for _,field in ipairs({'depth','height','z'}) do
      local labels={depth='Thickness',height='Height',z='Depth offset'}
      local value=ui:stepper(labels[field],selected[field],24,y,left-38)
      value=math.max(field=='depth' and 1 or -128,math.min(field=='depth' and 32 or 128,value or selected[field]))
      if value~=selected[field] then self:checkpoint(); selected[field]=value end
      y=y+32
    end
  end
  if ui:button('Undo',24,y,65,22) then self:undo() end
  if ui:button('Redo',95,y,65,22) then self:redo() end
  if ui:button('Remove',166,y,84,22) and selected then self:checkpoint(); table.remove(self.surfaces,self.selected); self.selected=math.max(1,self.selected-1) end
  y=y+32
  local choices={}; for i,s in ipairs(self.surfaces) do choices[i]={label=i..'  '..s.orientation..'  '..s.rect[3]..'x'..s.rect[4]} end
  local picked=ui:choiceList(choices,24,y,left-38,22,'asset_surfaces',math.max(22,sh-y-42))
  if picked then self.selected=picked; self.selection=nil end
  local vx=left+12
  if ui:button('Brush',vx,78,64,24,{active=self.tool=='brush'}) then self.tool='brush'; self.voxelSelection={} end
  if ui:button('Select voxels',vx+72,78,110,24,{active=self.tool=='select' and self.selectionShape=='box'}) then self.tool='select';self.selectionShape='box' end
  if ui:button('Line select',vx+190,78,92,24,{active=self.tool=='select' and self.selectionShape=='line'}) then self.tool='select';self.selectionShape='line' end
  if ui:button('Clear',vx+290,78,60,24) then self.voxelSelection={} end
  self.brushSize=math.max(1,math.min(16,ui:stepper('Size',self.brushSize,vx+364,78,math.max(120,sw-vx-388)) or self.brushSize))
  local r={x=vx,y=110,w=sw-left-36,h=sh-172}
  self:viewport(ui,r)
  if ui:button('Front',r.x,sh-50,66,24) then self.yaw=0; self.pitch=0 end
  if ui:button('Top',r.x+74,sh-50,66,24) then self.yaw=0; self.pitch=1.3 end
  if ui:button('Fit',r.x+148,sh-50,66,24) then
    self.zoom=1; self.panX=0; self.panY=0; self.yaw=.55; self.pitch=.45
    self.viewCenter=nil; self.viewSize=nil; self.fitScale=nil; self.dirty=true
  end
  if self.error then G.setColor(1,.5,.35); G.print(self.error,r.x+226,sh-44) end
  G.pop()
end
return E
