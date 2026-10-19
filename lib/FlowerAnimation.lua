-- Gen 2's native CGB flower strip and clock, adapted to the shared atlas path.
local V=...
local Assets=require('src.render.Assets')
local A={};local world;local sheets={};local specs=setmetatable({},{__mode='k'})
function A.bind(state)world=state end
function A.timer()return world and world.animTimer or 0 end
function A.spec(tileset)
 if not(world and tileset.generation==2 and tileset.anim)then return nil end
 local enabled=false
 for _,row in ipairs(tileset.anim.frames or {})do if row.func=='AnimateFlowerTile'then enabled=true;break end end
 if not enabled then return nil end
 local path=world.tilesets and world.tilesets.flowerFrames
 if not path then return nil end
 local first,second=world:flowerFrameFor(0),world:flowerFrameFor(2)
 local key=path..':'..first..':'..second
 local cached=specs[tileset];if cached and cached.key==key then return cached end
 local frames=sheets[key]
 if not frames then
  local ok,result=pcall(function()
   local strip=Assets.imageData(path);local out={}
   for _,row in ipairs({first,second})do
    local frame=love.image.newImageData(8,8);frame:paste(strip,0,0,0,(row-1)*8,8,8);out[#out+1]=frame
   end
   return out
  end)
  if not ok then return nil end
  frames=result;sheets[key]=frames
 end
 cached={key=key,tile=3,kind='frames',images={1,2},frameData=frames,
  sequence={1,1,2,2},nativeFlower=true}
 specs[tileset]=cached;return cached
end
function A.frames(tileset,tile)
 local spec=tile==3 and A.spec(tileset)
 return spec and spec.frameData or {}
end
return A
