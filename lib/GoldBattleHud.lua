-- Native Gold menus/HP tiles, on the Red battle's glass and viewport edges.
local V=...
local H={}

-- Use whole device pixels and whole source tiles, including the safe playfield
-- supplied by mobile skins. The native bottom UI accepts extra tile columns.
function H.layout(x,y,w,h,scale)
 local s=math.max(1,math.min(scale,math.floor(w/160),math.floor(h/144)))
 local tiles=math.floor(w/(8*s))
 local width=tiles*8*s
 local margin=math.min(4*s,math.floor(math.max(0,h-120*s)/2))
 local left=x+math.floor((w-width)/2)
 local top=y+margin
 local bottom=y+h-margin
 return {x=left,y=top,w=width,h=bottom-top,scale=s,columns=tiles,
  enemy={x=left,y=top,w=96*s,h=32*s},
  player={x=left+width-80*s,y=bottom-88*s,w=80*s,h=40*s},
  bottom={x=left,y=bottom-48*s,w=width,h=48*s}}
end

local inkShader
local INK=[[
 uniform vec3 paper;
 vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
  vec4 c=Texel(tex,tc);
  // Canvas RGB is premultiplied. Compare only actual opaque paper pixels.
  if(c.a>0.99 && (distance(c.rgb,paper)<0.012 || distance(c.rgb,vec3(1.0))<0.012))
   return vec4(0.0);
  return c*color;
 }
]]
function H.drawInk(canvas,x,y,s)
 local G=love.graphics
 inkShader=inkShader or G.newShader(INK)
 local Palette=require('src.render.GbcPalette')
 local colors=Palette.resolve(require('src.ui.gen2.Chrome').DEFAULT_BOX_PALETTE)
 local p=colors and colors[1] or {255,255,255}
 inkShader:send('paper',{p[1]/255,p[2]/255,p[3]/255})
 G.setShader(inkShader);G.setColor(1,1,1,1)
 G.setBlendMode('alpha','premultiplied');G.draw(canvas,x,y,0,s,s)
 G.setShader();G.setBlendMode('alpha')
end

function H.draw(state,e,shot,w,h,capture)
 local Chrome=require('src.ui.gen2.Chrome')
 local x,y,pw,ph=Chrome.playfieldRect(w,h)
 local fit=Chrome.fitScale(w,h)
 local field=require('src.render.Playfield')
 local dpi=type(field.pixelScale)=='function' and field.ratio() or 1
 x,y,pw,ph,fit=x*dpi,y*dpi,pw*dpi,ph*dpi,fit*dpi
 local r=H.layout(x,y,pw,ph,fit);local s=r.scale
 -- Each independent layer keeps all native visibility, HP chase, trainer
 -- party balls, translated labels, move swaps and yes/no prompts intact.
 local enemy=capture(e,'enemyHud',function()state:drawEnemyHud()end)
 local player=capture(e,'playerHud',function()state:drawPlayerHud()end)
 local boxes={}
 local actionBox
 local emptyMenu=state.phase=='menu' and (state.message==nil or state.message=='')
 local oldBox=Chrome.paletteBox
 Chrome.paletteBox=function(tx,ty,tw,th,...)
  -- Gold leaves the message blank at the action menu. Do not put an empty
  -- full-width frame over the stage just to hold a compact menu on its right.
  if emptyMenu and tx==0 and ty==12 then return end
  if emptyMenu and ty==12 and tx>0 then actionBox={x=tx,y=ty,w=tw,h=th} end
  local top=ty*8;local endY=math.min(96,(ty+th)*8)
  if top<endY then boxes[#boxes+1]={x=r.bottom.x+tx*8*s,y=r.bottom.y+(top-96)*s,w=tw*8*s,h=(endY-top)*s} end
  return oldBox(tx,ty,tw,th,...)
 end
 local ok,bottom=pcall(capture,e,'bottomHud',function()state:drawBottom(r.columns-20)end,r.columns*8,144)
 Chrome.paletteBox=oldBox
 if not ok then error(bottom,0) end
 local G=love.graphics
 local Glass=V.require('BattleGlass')
 -- HUD geometry uses framebuffer pixels. Convert once on window-coordinate
 -- engines while preserving the caller's playfield translation.
 G.push('all');G.scale(1/dpi,1/dpi);G.setShader();G.setColor(1,1,1,1)
 Glass.build(shot.canvas)
 local box={pw=w,ph=h,scale=1}
 local function panel(rect)
  Glass.panel({rect.x,rect.y,rect.w,rect.h},box)
 end
 if state:statusHUDVisible() then
  if (state.showEnemyHud and not state:hudCleared('enemy')) or state.ballRows.enemy then panel(r.enemy) end
  if (state.showPlayerHud and not state:hudCleared('player')) or state.ballRows.player then panel(r.player) end
 end
 H.drawInk(enemy,r.enemy.x,r.enemy.y,s)
 -- The native player's block starts at (72,56), unlike the enemy at (0,0).
 H.drawInk(player,r.player.x-72*s,r.player.y-56*s,s)
 if state:bottomUIVisible() then
  if emptyMenu then
   -- Capture native geometry: older apps have no menuLayout method.
   if actionBox then
    panel({x=r.bottom.x+actionBox.x*8*s,y=r.bottom.y+(actionBox.y-12)*8*s,w=actionBox.w*8*s,h=actionBox.h*8*s})
   else panel(r.bottom) end
  else panel(r.bottom) end
  -- Additional native boxes (move PP/type, learn/switch prompts, stats).
  for _,rect in ipairs(boxes)do panel(rect) end
  H.drawInk(bottom,r.bottom.x,r.bottom.y-96*s,s)
 end
 G.pop()
 return r
end
return H
