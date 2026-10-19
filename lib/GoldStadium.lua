-- Native Gold battle state -> shared Stadium actors. Native special picture
-- effects keep their original sprite path until the model can reproduce them.
local V=...
local Mon=V.require('StadiumMon')
local Pack=V.require('StadiumPack')
local Mon2=V.require('Stadium2BattleMon')
local S={};S.__index=S
local function externalModels()
 local mod=V.mod
 if not (mod and type(mod.find)=='function') then return nil end
 local ok,handle=pcall(mod.find,'STADIUM2_IMPORTER')
 local exports=ok and handle and handle.exports
 return Mon2.available(exports) and exports.models or nil
end
function S.sourceAvailable()
 return Pack.sourceAvailable() or externalModels()~=nil
end
local function ready(actor)
 return actor and ((actor.isReady and actor:isReady()) or actor.rig~=nil)
end
function S.new()
 local models=externalModels()
 local factory=models and function(side)return Mon2.new(side,models)end or Mon.new
 return setmetatable({player=factory('player'),enemy=factory('enemy'),at={},failed={},
  faintSlides={}},S)
end
function S:release()
 self.player:release();self.enemy:release();self.at={};self.anim=nil;self.failed={}
 self.afterSendOut=nil;self.faintSlides={}
end
function S:sync(state)
 local revision=Pack.revision or 0
 if self.revision~=revision then self:release();self.revision=revision end
 local data=state.game.data
 for _,side in ipairs({'player','enemy'})do
  local shown=state:activeMon(side)
  local actor=self[side]
  if self.at[side]~=shown then
   actor:release();self.at[side]=shown
  end
  local def=shown and data.pokemon[shown.species]
  local dex=def and (def.dex or def.index)
  local variant=shown and shown.shiny and 'shiny' or 'normal'
  if not dex and actor.species then
   actor:setSpecies(nil)
  elseif dex and self.failed[side]~=dex and not (actor.failed and actor.failed[dex])
    and (actor.species~=dex or actor.supportsShiny and actor.variant~=variant) then
   actor:setSpecies(dex,variant)
  end
  if actor.rig then Pack.keep(actor.species)end
 end
 -- Gold hides its native picture for the whole send-out animation. Start the
 -- model's entrance and smooth grow from that same transition, then let the
 -- model stand in for the hidden sprite while the ball effect plays.
 local after=state.afterSendOut
 if after~=self.afterSendOut then
  self.afterSendOut=after
  local actor=after and self[after.side]
  if ready(actor) then
   if actor:beginGrow() then actor:request('entrance') end
  end
 end
 -- BattleState starts the native faint slide only after the HP drain finishes.
 -- Reuse that exact event boundary for the skeletal collapse.
 local slide=state.faintSlide
 if slide then
  if self.faintSlides[slide.side]~=slide then
   self.faintSlides[slide.side]=slide
   local actor=self[slide.side]
   if ready(actor) then actor:request('faint') end
  end
 else
  self.faintSlides={}
 end
 local anim=state.anim
 if anim~=self.anim then
  self.anim=anim
  local move=anim and data.moves and data.moves[anim.animId]
  if move then
   local side=anim.env and anim.env.battleTurn==1 and 'enemy' or 'player'
   self[side]:attack(move.index)
  elseif anim and anim.animId=='ANIM_ENEMY_DAMAGE' then
   if self.enemy.supportsHit then self.enemy:request('hit')end
  elseif anim and anim.animId=='ANIM_PLAYER_DAMAGE' then
   if self.player.supportsHit then self.player:request('hit')end
  end
 end
end
function S:update(dt,state)
 self:sync(state)
 for _,side in ipairs({'player','enemy'})do
  local actor=self[side]
  actor:update(dt)
  actor.scale=actor.grow and actor:growScale() or 1
 end
end
local function eligible(state,side,mon,transition,actor)
 if not mon or mon.shiny and not actor.supportsShiny then return false end
 if side=='player' and state.showPlayerTrainer or side=='enemy' and state.showEnemyTrainer then return false end
 if (state:picBoxCleared(side) and not transition) or state:isUnderground(side,mon) then return false end
 if state:introGrayscale() then return false end
 if state.faintSlide and state.faintSlide.side==side and not transition then return false end
 local pose=state:animPicState(side)
 local substitute=mon.volatile and (mon.volatile.substitute or 0)>0
 if pose and pose.pic~=nil then substitute=pose.pic=='substitute' end
 if substitute then return false end
 -- These effects act on the native bitmap's rows or palette. Keeping that
 -- bitmap preserves their exact timing and prevents a duplicate model.
 local shaded=pose and pose.shade~=nil and pose.shade~=0xe4
 if pose and ((pose.hidden and not transition) or pose.lifted or pose.size
    or shaded or (pose.slide or 0)~=0) then return false end
 return true
end
function S:frame(state,arena,groundY)
 self:sync(state)
 local out={}
 for _,side in ipairs({'player','enemy'})do
  local actor=self[side]
  local mon=state:activeMon(side)
  local send=state.afterSendOut
  local sending=send and send.side==side and send.mon==mon and actor.grow~=nil
  local slide=state.faintSlide
  local fainting=slide and slide.side==side
    or actor.state=='faint' and actor.finished and actor:finished()
  local transition=sending or fainting
  if ready(actor) and eligible(state,side,mon,transition,actor) then
   local cell=arena[side];local other=arena[side=='player' and 'enemy' or 'player']
   local ok,record=pcall(function()
    local matrix=actor:matrix(cell[1],groundY,cell[2],other[1]-cell[1],other[2]-cell[2])
    if matrix and actor:build() then return {rig=actor.rig,actor=actor,model=matrix} end
   end)
   if ok then out[side]=record else
    self.failed[side]=actor.species;actor:release()
    if V.mod and V.mod.log then V.mod.log:warn('Gold model pose failed; using native sprite: %s',tostring(record)) end
   end
  end
 end
 return out
end
return S
