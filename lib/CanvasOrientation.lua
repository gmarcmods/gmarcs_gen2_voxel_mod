-- The voxel compositor owns its completed canvas, including the iOS/LOVE12
-- Y convention. Do not rely on patched engine Renderer helper functions.
local O={}
function O.mirrors()
 return love.system and love.system.getOS and love.system.getOS()=='iOS'
  and type(love.getVersion)=='function'and (love.getVersion())>=12 or false
end
function O.draw(canvas,x,y,sx,sy)
 sx,sy=sx or 1,sy or 1
 if O.mirrors()then
  love.graphics.draw(canvas,x,y+canvas:getHeight()*sy,0,sx,-sy)
 else love.graphics.draw(canvas,x,y,0,sx,sy)end
end
-- CPU-projected FX use screen coordinates. Match the raw 3D target before
-- its final mirror so anchors and glyphs both end upright on screen.
function O.withRawFx(draw)
 if not O.mirrors()then return draw()end
 local G=love.graphics;local bound=G.getCanvas()
 if bound and not bound.getHeight then bound=bound[1]or bound.canvas end
 if bound and not bound.getHeight then bound=bound.canvas end
 local height=bound and bound.getHeight and bound:getHeight()
 if not height then return draw()end
 G.push();G.translate(0,height);G.scale(1,-1)
 local ok,result=pcall(draw)
 G.pop()
 if not ok then error(result,0)end
 return result
end
return O
