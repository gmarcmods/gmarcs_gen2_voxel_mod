-- Gold adapter for the original Red diorama battle camera and renderer.
-- BattleState still owns every turn, animation, menu and result. We capture
-- its live pic/effect layers, stand them on the map, and draw its native HUD.
local V=...
local B={}
local entries=setmetatable({},{__mode='k'})
local Cam=V.require('BattleCam')
local Scene=V.require('BattleScene')
local Voxel=V.require('VoxelState')
local Chrome=require('src.ui.gen2.Chrome')
B.setting=V.require('ModSetting').new('battles','3D-BTL',
 {true,'flatB','stadium','stadiumB',false},{'MAP','PLATFORMS','STADIUM A','STADIUM B','OFF'})
 :setGate(function(value)
  return value~='stadium' and value~='stadiumB' or V.require('GoldStadium').sourceAvailable()
 end)
local function modelsSelected(mode)return mode=='stadium' or mode=='stadiumB' end
function B.arenaFor(world,surf,mode)
 if mode==false then return nil end
 if mode=='flatB' or mode=='stadiumB' then return V.require('BattlePlatforms').arena(world.map) end
 local p=world.player
 return V.require('BattleArena').find(world.map,p.cellX,p.cellY,surf)
end
local function enabled(s)
 return B.setting:get()~=false and Voxel.active() and s.game and s.game.world and s.battle
end
function B.active()
 local game=require('src.core.Game')
 local top=game.stack and game.stack:top()
 return top and enabled(top) and entries[top] and entries[top].shot and top or nil
end
function B.lastShot(s)return entries[s] and entries[s].shot end
function B.lastHud(s)return entries[s] and entries[s].hud end
function B.lastPic(s,side)return entries[s] and entries[s][side] end
local function capture(e,key,fn,w,h)
 w,h=w or 160,h or 144
 local G=love.graphics
 local canvas=e[key]
 if not canvas or canvas:getWidth()~=w or canvas:getHeight()~=h then
  if canvas then canvas:release() end
  canvas=G.newCanvas(w,h,{dpiscale=1});canvas:setFilter('nearest','nearest');e[key]=canvas
 end
 local previous=G.getCanvas()
 G.push('all');G.setCanvas(canvas);G.origin();G.setScissor();G.setShader();G.setDepthMode();G.setColor(1,1,1,1);G.clear(0,0,0,0)
 local ok,err=pcall(fn)
 G.pop();G.setCanvas(previous);if not ok then error(err,0)end
 return canvas
end
local function sideTexture(s,e,side)
 local back=side=='player'
 local trainer=back and s.showPlayerTrainer or not back and s.showEnemyTrainer
 local oldPic,oldFill=s.pic,s.animView and s.animView.fillBackground
 local oldFrame=s.frontAnimFrame
 local oldTrainer=s.enemyTrainerImage
 if not back and trainer then
  s.enemyTrainerImage=V.require('BattleCutout').image(oldTrainer,s.enemyTrainerPath,s.enemyTrainerTrueColor)
 end
 -- Front pictures give the same facing pair as the Red mod. Layout and
 -- all visibility/substitute/faint rules remain the native side's rules.
 s.pic=function(self,mon,isBack)
  if not trainer then isBack=false end
  local image,trueColor,path=oldPic(self,mon,isBack)
  return V.require('BattleCutout').image(image,path,trueColor),trueColor,path
 end
 if oldFrame then
  s.frontAnimFrame=function(self,mon)
   local sheet,quad,size=oldFrame(self,mon)
   if sheet and self.animData and self.animSheetPath then
    local data=self:animData(mon)
    local path,replaced=self:animSheetPath(mon,data)
    sheet=V.require('BattleCutout').image(sheet,path,replaced)
   end
   return sheet,quad,size
  end
 end
 if s.animView then s.animView.fillBackground=function()end end
 local function drawSide()
  local draw=function()s:drawPic(s:activeMon(side),back)end
  if s.anim and s.animView then
   s.animView:present(s.anim,draw,s.battle)
   local pose=s:animPicState(side)
   if pose and pose.lifted then s.liftedPass=true;draw();s.liftedPass=nil end
  elseif s.slideFrame and s.slideFrame<72 then
   local G=love.graphics;G.push();G.translate((back and -1 or 1)*(72-s.slideFrame)*2,0);draw();G.pop()
  else draw()end
 end
 local ok,canvas=pcall(function()
  return V.require('BattleSprites').withFrame(s,side,function()
   return capture(e,side,drawSide)
  end)
 end)
 s.pic=oldPic;s.frontAnimFrame=oldFrame;s.enemyTrainerImage=oldTrainer
 if s.animView then s.animView.fillBackground=oldFill end;s.liftedPass=nil
 if not ok then error(canvas,0)end
 return {canvas=canvas,ax=back and 40 or 124,ay=back and 96 or 56,trainer=trainer}
end
local function entry(s)
 local mode=B.setting:get()
 local e=entries[s]
 if e and e.mode==mode then return e end
 local w=s.game.world;local p=w.player
 local surf=require('src.world.gen2.FieldMoves').isSurfing(w.playerState)
 e=e or {token=0}
 if e.models then e.models:release();e.models=nil end
 e.arena=B.arenaFor(w,surf,mode);e.mode=mode;e.shot=nil
 if e.arena and modelsSelected(mode) then e.models=V.require('GoldStadium').new() end
 entries[s]=e;Cam.reset()
 return e
end
-- The HUD uses logical window coordinates; the world canvas and projection
-- use framebuffer pixels. Mixing those scales shrinks actors on retina/mobile.
function B.frameScale(winW,winH)
 local pw,ph=Scene.pixelSize()
 local density=math.min(pw/math.max(1,winW),ph/math.max(1,winH))
 return Chrome.fitScale(winW,winH)*density
end
function B.render(s,winW,winH)
 if not enabled(s) then return false end
 local e=entry(s);if not e.arena then return false end
 local world=s.game.world;V.require('Gen2').neighborsOf(world)
 local models=e.models and e.models:frame(s,e.arena,Scene.groundY(e.arena.map or world.map,e.arena)) or {}
 local textures={models=models,anchors={player={40,96},enemy={124,56}}}
 for _,side in ipairs({'player','enemy'})do
  if not models[side] then textures[side]=sideTexture(s,e,side) end
 end
 if s.anim and s.animView or s.expBurst then
  textures.fx=capture(e,'fx',function()
   if s.anim and s.animView then s.animView:drawObjects(s.anim,s.battle)end
   if s.expBurst then s:drawExpBurst()end
  end)
 end
 e.token=e.token+1
 Scene.panelScale=B.frameScale(winW,winH)
 local G=love.graphics
 local previous=G.getCanvas()
 G.push('all')
 G.origin();G.setScissor()
 local ok,shot=pcall(Scene.render,world,e.arena,textures,e.token)
 G.pop();G.setCanvas(previous);Scene.panelScale=nil
 if not ok then error(shot,0)end
 if not shot then return false end
 e.shot=shot
 G.push('all');G.setShader();G.setColor(1,1,1,1)
 G.setBlendMode('alpha','premultiplied')
 V.require('CanvasOrientation').draw(shot.canvas,0,0,winW/shot.pw,winH/shot.ph)
 G.setBlendMode('alpha')
 local good,err=pcall(function()
  e.hud=V.require('GoldBattleHud').draw(s,e,shot,winW,winH,capture)
  -- Other mods still receive the native battle.overlay seam in GB space.
  local surround=Chrome.worldSurround;Chrome.worldSurround=true
  local drawn,why=pcall(Chrome.withPanel,winW,winH,1,1,1,function()
   s:drawScene(function()end)
  end,Chrome.fitScale(winW,winH))
  Chrome.worldSurround=surround
  if not drawn then error(why,0)end
 end)
 G.pop()
 if not good then error(err,0)end
 return true
end
function B.install()
 local ok,State=pcall(require,'src.ui.gen2.BattleState')
 if not ok or State.gen2VoxelBattle then return end
 State.gen2VoxelBattle=true
 local draw,update=State.drawWidescreen,State.update
 local exit=State.exit
 function State:exit(...)
  local e=entries[self]
  if e and e.models then e.models:release() end
  entries[self]=nil
  if type(exit)=='function' then return exit(self,...) end
 end
 local bgMode,panelSize,panelScale=State.bgMode,State.panelSize,State.battlePanelScale
 local function staged(s)return enabled(s) and entry(s).arena end
 function State:bgMode()
  if staged(self) then return 'voxel' end
  return bgMode(self)
 end
 function State:panelSize()
  if staged(self) then return 160,144 end
  return panelSize(self)
 end
 function State:battlePanelScale(w,h)
  if staged(self) then return Chrome.fitScale(w,h) end
  return panelScale(self,w,h)
 end
 function State:drawWidescreen(w,h)
  if B.render(self,w,h) then return end
  return draw(self,w,h)
 end
 function State:update(dt,...)
  local e=entries[self]
  if e and e.models then e.models:update(dt,self) end
  if B.active()==self then
   V.require('CamControl').tick(dt);Cam.update(dt)
  end
  return update(self,dt,...)
 end
end
return B
