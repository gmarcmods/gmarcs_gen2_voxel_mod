-- Optional battle artwork is a provider contract, independent of the ROM
-- decoder, cache layout and voxel geometry. Native art remains the default.
local V=...
local B={}
local registered={}
B.setting=V.require('ModSetting').new('battleSprites','BTL SPRITES',
 {'native','gen5_bw','gen5_b2w2'},{'NATIVE','BLACK/WHITE','BLACK 2/WHITE 2'})
local function valid(p)
 return type(p)=='table' and p.apiVersion==2 and type(p.frame)=='function'
  and type(p.capabilities)=='table' and p.capabilities.contract=='national-dex-battle-sprites'
end
function B.register(source,label,provider)
 assert(type(source)=='string' and source~='native' and valid(provider),'invalid battle sprite provider')
 registered[source]=provider
 local found=false
 for _,s in ipairs(B.setting.values)do if s==source then found=true end end
 if not found then
  B.setting.values[#B.setting.values+1]=source
  B.setting.labels[#B.setting.labels+1]=label or source
  if V.refreshSettings then V.refreshSettings()end
 end
 return true
end
local function provider(source)
 if registered[source]then return registered[source]end
 if source~='gen5_bw' and source~='gen5_b2w2' then return nil end
 if not(V.mod and V.mod.find)then return nil end
 local ok,h=pcall(V.mod.find,'GEN5_PRIVATE_SPRITES')
 local p=ok and h and h.exports
 return valid(p)and p or nil
end
function B.frame(state,side)
 local source=B.setting:get()
 if source=='native' then return nil end
 if side=='player' and state.showPlayerTrainer or side=='enemy' and state.showEnemyTrainer then return nil end
 local mon=state:activeMon(side)
 local def=mon and state.game and state.game.data and state.game.data.pokemon[mon.species]
 local dex=def and(def.dex or def.index)
 -- Unown's personality-dependent forms are not base-form artwork.
 if not dex or dex==201 or mon.species=='UNOWN' then return nil end
 local pose=state.animPicState and state:animPicState(side)
 if pose and pose.pic=='substitute' or mon.volatile and(mon.volatile.substitute or 0)>0 then return nil end
 local p=provider(source)
 if not p then return nil end
 local ok,f=pcall(p.frame,{source=source,dex=dex,side='front',shiny=mon.shiny,
  gender=mon.gender,form=0,battleId=state,battlerId=side,mon=mon})
 if not ok or type(f)~='table' or not f.image then return nil end
 if type(f.width)~='number' or type(f.height)~='number' or f.width%1~=0 or f.height%1~=0
  or f.width<1 or f.height<1 or f.width>256 or f.height>256 then return nil end
 return f
end
-- Keep the native draw path: hidden boxes, send-out, substitute, fainting,
-- slides and attack effects stay owned by the game. Only its picture changes.
function B.withFrame(state,side,draw)
 local frame=B.frame(state,side)
 if not frame then return draw()end
 local pic,front,scale,drawPic=state.pic,state.frontAnimFrame,state.picScale,state.drawPic
 local mon=state:activeMon(side)
 local k=math.min(1,56/frame.width,56/frame.height)
 state.pic=function(self,m,back)
  if m==mon then return frame.image,true,'provider/'..B.setting:get()end
  return pic(self,m,back)
 end
 state.frontAnimFrame=function(self,m)
  if m==mon then return nil end
  if front then return front(self,m)end
 end
 state.picScale=function(self,path,m,back)
  if m==mon then return k end
  return scale(self,path,m,back)
 end
 -- Native oversized fronts pin to the box's top-left. Recenter them before
 -- applying native animation transforms, without resampling a new texture.
 state.drawPic=function(self,m,back)
  if m~=mon or back then return drawPic(self,m,back)end
  local G=love.graphics
  G.push()
  G.translate(-math.max(0,math.floor((frame.width-56)/2)),-math.max(0,frame.height-56))
  local ok,err=pcall(drawPic,self,m,back)
  G.pop()
  if not ok then error(err,0)end
 end
 local ok,result=pcall(draw)
 state.pic,state.frontAnimFrame,state.picScale,state.drawPic=pic,front,scale,drawPic
 if not ok then error(result,0)end
 return result
end
return B
