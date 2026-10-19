-- Cave rim texels are reused by shores, open floor and actual solid rock.
-- The native collision cell owns elevation; never extrude a walkable bank.
local C={};local copies=setmetatable({},{__mode='k'})
local caves={TILESET_CAVE=true,TILESET_DARK_CAVE=true,TILESET_ICE_PATH=true}
local rocks={cave_rim=true,cave_plateau=true,ice_wall=true,wall=true}
function C.at(map,shape,tx,ty)
 local id=map.tileset and map.tileset.id
 if not shape or not caves[id] or not rocks[shape.class]then return shape end
 if map.def and map.def.environment and map.def.environment~='CAVE'then return shape end
 local kind='solid'
 if tx and ty then
  local cx,cy=math.floor(tx/2),math.floor(ty/2)
  if map.isWaterCell and map:isWaterCell(cx,cy)then kind='water'
  elseif map.isWalkableCell and map:isWalkableCell(cx,cy)and map.isWaterCell then
   for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
    if map:isWaterCell(cx+d[1],cy+d[2])then kind='floor';break end
   end
   local coll=map.cellCollision and map:cellCollision(cx,cy)
   if kind=='solid'and coll and coll>=0xb0 and coll<=0xb7 then kind='lip'end
  end
 end
 local key=kind..':'..id
 local cached=copies[shape];if not cached then cached={};copies[shape]=cached end
 if cached[key]then return cached[key]end
 local out={};for k,v in pairs(shape)do out[k]=v end
 if kind=='solid'then out.sideTile=id=='TILESET_ICE_PATH'and 18 or 22
 else
  out={class=kind=='water'and'water'or kind=='lip'and'ledge'or'ground',
   base=kind=='lip'and'ledge'or'ground',h=kind=='water'and -2 or kind=='lip'and 2 or 0,
   art='flat',flat=true,authored=true}
  if kind=='floor'or kind=='lip'then out.topTile=id=='TILESET_ICE_PATH'and 25 or 1
  elseif id~='TILESET_ICE_PATH'then out.topTile=20 end
  if kind=='lip'then out.sideTile=id=='TILESET_ICE_PATH'and 18 or 22 end
 end
 cached[key]=out;return out
end
return C
