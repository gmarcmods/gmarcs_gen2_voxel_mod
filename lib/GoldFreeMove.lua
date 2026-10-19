-- Gold never calls the Gen 1 handleInput facade. Adapt its real movement
-- seam while leaving World:stepBody in charge of scripts and cell arrivals.
local V=...
local F=V.require('FirstPerson')
local Free=V.require('FreeMove')
local G={}
local pending=setmetatable({},{__mode='k'})
local function direction(x,z)
 if math.abs(x)>math.abs(z) then return x>0 and 'right' or 'left' end
 return z>0 and 'down' or 'up'
end
function G.install()
 local ok,W=pcall(require,'src.world.gen2.World')
 if not ok or W.gen2VoxelNativeFreeMove then return end
 W.gen2VoxelNativeFreeMove=true
 local Player=require('src.world.gen2.Player')
 local Permissions=require('src.world.gen2.Permissions')
 local Field=require('src.world.gen2.FieldMoves')
 local Bike=require('src.world.gen2.Bike')
 local Runtime=require('src.mods.Runtime')
 local nativeMove,nativePoll,nativeUpdate=W.movePlayer,W.pollInput,Player.update
 local adapters=setmetatable({},{__mode='k'})
 local inputs=setmetatable({},{__mode='k'})
 local function release(w)
  if Free._pos() and w.player then
   local p=w.player
   p.voxelFreeWalk=nil
   -- A ledge/script can take over between input polls. Its in-flight
   -- position belongs to Player:update, not the free-walk snap-to-grid.
   if not p.moving then p.px,p.py=p.cellX*16,p.cellY*16 end
   Free.drop()
  end
 end
 local function adapter(w)
  if adapters[w] then return adapters[w] end
  local a={}
  function a:freeMoveBlocked(p,x,y)
   if x==p.cellX and y==p.cellY then return nil end
   local map=w.map
   if not map:inBounds(x,y) then return 'bounds' end
   local coll=map:cellCollision(x,y)
   if not (Field.isSurfing(w.playerState) and Permissions.surfable(coll)
       or not Field.isSurfing(w.playerState) and Permissions.isWalkable(coll)) then return 'tile' end
   local function perm(sx,sy,dir)
    return Permissions.stepPermitted(function(cx,cy)return w:cellCollisionAcross(map,cx,cy)end,sx,sy,dir)
   end
   if x~=p.cellX and not perm(p.cellX,p.cellY,x>p.cellX and 'right' or 'left') then return 'tile' end
   if y~=p.cellY and not perm(x,p.cellY,y>p.cellY and 'down' or 'up') then return 'tile' end
   local npc=w:npcAt(x,y)
   if npc and npc~=p and not npc.passable then return 'entity' end
   for _,e in ipairs(w.entities or {})do
    if e~=p and not e.passable and ((e.cellX==x and e.cellY==y) or (e.moving and e.targetX==x and e.targetY==y)) then return 'entity' end
   end
   return nil
  end
  function a:freeMoveSpeed()
   local p=w.player
   local frames=Bike.stepFrames(w.playerState,p.facing,w:downhill(),Player.STEP_FRAMES)
   if Runtime.wantsHook('movement.speed') then
    frames=Runtime.call('movement.speed',function(n)return n end,frames,{
     onBike=Field.isBiking(w.playerState),surfing=Field.isSurfing(w.playerState),
     downhill=w:downhill() and true or false,playerState=w.playerState,
     player=p,input=w.game.input,save=w.game.save})
   end
   return 16/math.max(1,math.floor(tonumber(frames) or Player.STEP_FRAMES))
  end
  function a:onStepComplete()
   local p=w.player
   pending[p]={world=w,map=w.map,x=p.cellX,y=p.cellY}
   w.turningDirection=p.facing
  end
  function a:checkEdgeExit(dir)return w:tryConnection(dir)end
  function a:checkLedgeHop(dir)return w:tryLedgeJump(dir)end
  function a:checkBoulderPush(dir)
   local delta={up={0,-1},down={0,1},left={-1,0},right={1,0}}
   local d=delta[dir];local p=w.player
   return w:tryPushBoulder(dir,p.cellX+d[1],p.cellY+d[2])
  end
  -- Gold checks warp mats in World:stepBody before movement dispatch.
  function a:canCollisionWarp()return false end
  setmetatable(a,{__index=function(_,k)
   local value=w[k]
   if type(value)=='function' then return function(_,...)return value(w,...)end end
   return value
  end,__newindex=function(_,k,value)w[k]=value end})
  adapters[w]=a;return a
 end
 function Player:update(...)
  local landed=nativeUpdate(self,...)
  local arrival=pending[self];pending[self]=nil
  if arrival and arrival.world.map==arrival.map and self.cellX==arrival.x and self.cellY==arrival.y then
   -- Feed the SAME landing branch as a completed grid step: warps, coord
   -- scripts, step counters and encounters, exactly once next logic tick.
   self.stepFlip=not self.stepFlip
   return true
  end
  return landed
 end
 function W:pollInput(input,...)
  nativePoll(self,input,...)
  inputs[self]=input
  if not F.driving(self) then release(self);return end
  if self:busy() or self.player.moving then self.player.voxelFreeWalk=nil;return end
  local mx,mz=F.moveVector(input);local x,z=F.moveWorld(mx,mz)
  if mx~=0 or mz~=0 then self.heldDir=direction(x,z)
  elseif not self:downhill() then self.heldDir=nil;self.player.facing=F.pointBody(0,0);self.player.voxelFreeWalk=nil end
 end
 function W:movePlayer(dir,...)
  local p=self.player;local coll=self:playerCollision()
  local d={up={0,-1},down={0,1},left={-1,0},right={1,0}}
  local dv=d[dir]
  local shore=Field.isSurfing(self.playerState) and dv
    and Permissions.surfable(self.map:cellCollision(p.cellX+dv[1],p.cellY+dv[2]))=='land'
  -- Scripted grid moves and forced tiles keep their native behavior.
  if not F.driving(self) or self:busy() or p.moving or Permissions.isIce(coll)
     or Permissions.currentDirection(coll) or Permissions.doorForcedDirection(coll)
     or Permissions.isWhirlpool(coll) or shore or self:downhill() then
   release(self);return nativeMove(self,dir,...)
  end
  local x,y,map=p.px,p.py,self.map
  Free.tick(adapter(self),inputs[self])
  if self.map==map and not p.moving then
   -- Free movement does not enter Player's grid-step state. Advance the
   -- normal 16px walking cycle by actual travel, not the bonk clock.
   local distance=math.sqrt((p.px-x)^2+(p.py-y)^2)
   local walk=p.voxelFreeWalk or {distance=0}
   walk.distance=walk.distance+distance
   walk.moving=distance>0.0001
   p.voxelFreeWalk=walk
  else p.voxelFreeWalk=nil end
  return 'free'
 end
end
return G
