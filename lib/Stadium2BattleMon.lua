-- Scene-neutral Stadium 2 actor for Gold's voxel battle stage. The importing
-- mod owns cached source assets; each live battler owns/releases its instance.
local V=...
local Mat4=V.require('Mat4')
local Voxel3D=V.require('Voxel3D')
local A={};A.__index=A
A.GROW_SECONDS=0.34
A.REF_HEIGHT=14
A.MEDIAN_HEIGHT=52.25
A.SQUASH=0.5
A.MIN_HEIGHT=5
A.MAX_HEIGHT=18

local function bounds(instance)
 local ok,b=pcall(instance.bounds,instance)
 if not ok or type(b)~='table' then return nil end
 local lo=b.min or b.minimum or b[1]
 local hi=b.max or b.maximum or b[2]
 if type(lo)~='table' or type(hi)~='table' then return nil end
 local minY=tonumber(lo[2] or lo.y)
 local maxY=tonumber(hi[2] or hi.y)
 if not (minY and maxY and maxY>minY) then return nil end
 return minY,maxY
end

function A.available(exports)
 local m=exports and exports.models
 if not (m and tonumber(m.apiVersion)>=2 and type(m.newInstance)=='function'
       and m.matrix and type(m.matrix.transform)=='function') then return false end
 local ok,caps=pcall(m.capabilities)
 return ok and type(caps)=='table' and caps.sceneNeutralDraw==true
end

function A.new(side,models)
 return setmetatable({side=side,models=models,species=nil,instance=nil,state=nil,
  supportsShiny=true,supportsHit=true,scale=1,grow=nil,done=false,failed={}},A)
end

function A:isReady() return self.instance~=nil end
function A:release()
 if self.instance then pcall(self.instance.release,self.instance) end
 self.instance=nil;self.species=nil;self.variant=nil;self.state=nil;self.grow=nil;self.done=false
end

function A:setSpecies(dex,variant)
 variant=variant=='shiny' and 'shiny' or 'normal'
 if dex==self.species and variant==self.variant then return self.instance~=nil end
 self:release();self.species=dex
 if not (type(dex)=='number' and dex>=1 and dex<=251 and dex%1==0) then return false end
 if self.failed[dex] then self.species=nil;return false end
 local ok,instance=pcall(self.models.newInstance,dex,variant,
  {textureFilter='nearest',anchorTravel=true})
 if not ok or type(instance)~='table' or type(instance.draw)~='function' then
  self.failed[dex]=true;self.species=nil;return false
 end
 self.instance=instance;self.variant=variant
 self:play('idle',true)
 return true
end

function A:play(state,loop)
 if not self.instance then return false end
 local ok,started=pcall(self.instance.playContext,self.instance,state,loop==true)
 if ok and started~=false then self.state=state;self.done=false;return true end
 return false
end

local RANK={idle=0,entrance=1,attack=2,hit=2,faint=3}
function A:request(state)
 if not self.instance or self.state=='faint' then return false end
 if (RANK[state] or 0)<(RANK[self.state] or 0) then return false end
 return self:play(state,state=='idle')
end

function A:attack(moveId)
 if not self.instance or not (moveId and moveId>0) then return false end
 local ok,started=pcall(self.instance.playMove,self.instance,moveId,false)
 if ok and started~=false then self.state='attack';self.done=false;return true end
 return self:request('attack')
end

function A:update(dt)
 if self.instance then
  pcall(self.instance.update,self.instance,dt,{weather='clear'})
  if self.grow then
   self.grow=math.min(A.GROW_SECONDS,self.grow+dt)
   if self.grow>=A.GROW_SECONDS then self.grow=nil end
  end
  if self.state=='faint' and not self.grow then
   local ok,done=pcall(self.instance.isFinished,self.instance)
   self.done=ok and done==true
  end
 end
end

function A:beginGrow()
 if not self.instance then return false end
 self.grow=0;return true
end
function A:growScale()
 if not self.grow then return 1 end
 return math.max(0.01,math.min(1,self.grow/A.GROW_SECONDS))
end
function A:finished() return self.done end
function A:build() return self.instance~=nil end

function A:matrix(x,groundY,z,faceX,faceZ)
 if not self.instance then return nil end
 local minY,maxY=bounds(self.instance)
 if not minY then return nil end
 local rawHeight=maxY-minY
 local height=A.REF_HEIGHT*(rawHeight/A.MEDIAN_HEIGHT)^A.SQUASH
 height=math.max(A.MIN_HEIGHT,math.min(A.MAX_HEIGHT,height))
 local scale=height/rawHeight*(self.scale or 1)
 local yaw=0
 if faceX and faceZ and (faceX~=0 or faceZ~=0) then yaw=math.atan2(faceX,faceZ) end
 self.yaw=yaw
 return self.models.matrix.transform({
  position={x,groundY-minY*scale,z},rotation={0,yaw,0},scale=scale,
 })
end

function A:draw(modelMatrix)
 if not self.instance or not Voxel3D.vp then return false end
 local cam=Voxel3D.camera
 if not (cam and cam.eye and cam.focus) then return false end
 local view=Mat4.lookAt(cam.eye,cam.focus,cam.up or {0,1,0})
 local ok,result=pcall(self.instance.draw,self.instance,{
  modelMatrix=modelMatrix,
  camera={view=view,viewProjection=Voxel3D.vp},
  light={direction={-0.4,0.8,0.25},ambient={0.38,0.40,0.48},
   diffuse={0.95,0.90,0.82}},
 })
 return ok and result~=false
end

return A
