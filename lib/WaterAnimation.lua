-- Native Gen 2 VRAM water frames. Its overworld does not tick Gen 1's clock.
local A={};local world;local sheets={};local cached=setmetatable({},{__mode='k'})
function A.bind(state)world=state end
function A.frame(map)
 map=map or(world and world.map)
 if map and map.tileset and map.tileset.generation==2 and love and love.timer and love.timer.getTime then
  return math.floor(love.timer.getTime()*60)
 end
end
function A.phase(spec)
 return world and world.waterFrameFor(world.animTimer or 0)-1 or 0
end
function A.specs(tileset)
 if not(world and tileset.generation==2 and tileset.anim)then return{}end
 local path=world.tilesets and world.tilesets.waterFrames
 if not path then return{}end
 local result=cached[tileset]
 if result and result.path==path then return result end
 result={path=path}
 for _,row in ipairs(tileset.anim.frames or {})do if row.func=='AnimateWaterTile'and row.tile then
  local frames=sheets[path]
  if not frames then
   local ok,value=pcall(function()
    local strip=require('src.render.Assets').imageData(path);local out={}
    for i=1,4 do local frame=love.image.newImageData(8,8);frame:paste(strip,0,0,0,(i-1)*8,8,8);out[i]=frame end
    return out
   end)
   if not ok then return{}end
   frames=value;sheets[path]=frames
  end
  result[#result+1]={tile=row.tile,kind='frames',images={1,2,3,4},frameData=frames,
   sequence={1,2,3,4},nativeWater=true}
 end end
 cached[tileset]=result;return result
end
return A
