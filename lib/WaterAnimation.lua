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
 if spec.layer and world and world.animRow then return world:animRow(spec.layer)-1 end
 return world and world.waterFrameFor(world.animTimer or 0)-1 or 0
end
function A.specs(tileset)
 if not(world and tileset.generation==2 and tileset.anim)then return{}end
 local path=world.tilesets and world.tilesets.waterFrames
 local kinds={AnimateWhirlpoolTile='whirlpool',AnimateTowerPillarTile='tower',
  AnimateLavaBubbleTile1='lava1',AnimateLavaBubbleTile2='lava2'}
 local result=cached[tileset]
 if result and result.path==path then return result end
 result={path=path}
 for _,row in ipairs(tileset.anim.frames or {})do if (row.func=='AnimateWaterTile'or kinds[row.func]or row.func=='WriteTileFromAnimBuffer'and row.scroll)and row.tile then
  local sheet=row.func=='AnimateWaterTile'and path or row.sheet
  local count=row.func=='AnimateWaterTile'and 4 or row.frames or 8
  local kind=row.scroll and 'scroll'or kinds[row.func]or'water'
  if row.scroll then
   result[#result+1]={tile=row.tile,kind='scroll',scroll=row.scroll,sequence={1,2,3,4,5,6,7,8},
    nativeWater=true,layer={kind='scroll'}}
  elseif sheet then
  local frames=sheets[sheet]
  if not frames then
   local ok,value=pcall(function()
    local strip=require('src.render.Assets').imageData(sheet);local out={}
    for i=1,count do local frame=love.image.newImageData(8,8);frame:paste(strip,0,0,0,(i-1)*8,8,8);out[i]=frame end
    return out
   end)
   if not ok then return{}end
   frames=value;sheets[sheet]=frames
  end
  local sequence={};for i=1,count do sequence[i]=i end
  result[#result+1]={tile=row.tile,kind='frames',images=sequence,frameData=frames,
   sequence=sequence,nativeWater=true,layer={kind=kind}}
  end
 end end
 cached[tileset]=result;return result
end
return A
