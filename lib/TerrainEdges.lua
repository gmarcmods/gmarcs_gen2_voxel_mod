-- Opt-in collision-aware low terrain. Rock texels are reused by jump faces,
-- river banks and actual mountains; the surrounding game cells distinguish them.
local Permissions
local indices=setmetatable({},{__mode='k'})
local E={}
local dirs={{0,-1,'down'},{0,1,'up'},{-1,0,'right'},{1,0,'left'}}
local function index(c,name)
 local cache=indices[c]
 if not cache then cache={};indices[c]=cache end
 if not cache[name] then local s={}for _,t in ipairs(c[name])do s[t]=true end;cache[name]=s end
 return cache[name]
end
function E.validate(c)
 if type(c)~='table' then return false,'terrain edge config required' end
 for _,name in ipairs({'tiles','ledgeTiles','capTiles','ledgeBlocks'})do
  if name~='ledgeBlocks' or c[name]~=nil then
  if type(c[name])~='table' then return false,'terrain edge tile list required' end
  for _,t in ipairs(c[name])do if type(t)~='number' or t%1~=0 or t<0 or t>255 then return false,'invalid edge tile' end end
  end
 end
 if type(c.shoreClass)~='string' or c.shoreClass=='' then return false,'shore class required' end
 for _,name in ipairs({'lipHeight','shoreHeight','topTile'})do
  local n=c[name];local limit=name=='topTile' and 255 or 8
  if type(n)~='number' or n~=n or n%1~=0 or n<0 or n>limit then return false,'invalid edge '..name end
 end
 return true
end
local function shape(shapes,c,kind,tile)
 local cache=shapes.edgeShapes
 if not cache then cache={};shapes.edgeShapes=cache end
 local key=kind..':'..tile
 if not cache[key] then
  cache[key]={class=kind=='shore' and c.shoreClass or 'ledge',base='ledge',
   h=kind=='shore' and c.shoreHeight or c.lipHeight,art='top',authored=true,
   topTile=c.topTile,sideTile=tile}
 end
 return cache[key]
end
function E.at(map,shapes,s,tile,tx,ty)
 local c=shapes.edges
 if not c or not s or not index(c,'tiles')[tile] or not map.cellCollision then return s end
 -- Block-scoped cave rims reuse full-wall art. Resolve the whole native
 -- jump block, including corners, and leave every other wall untouched.
 if c.ledgeBlocks then
  local block=map.blockId and map:blockId(math.floor(tx/4),math.floor(ty/4))
  return block and index(c,'ledgeBlocks')[block] and shape(shapes,c,'lip',tile) or s
 end
 local cx,cy=math.floor(tx/2),math.floor(ty/2)
 -- A bank may occupy half a surfable cell. Test every edge direction;
 -- the old below-only rules left north/west/east banks as 16px walls.
 if map:isWaterCell(cx,cy) then return shape(shapes,c,'shore',tile) end
 for _,d in ipairs(dirs)do
  local t=map:tileAt(tx+d[1],ty+d[2])
  local neighbor=shapes[t]
  if neighbor and (neighbor.base or neighbor.class)=='water' then return shape(shapes,c,'shore',tile) end
 end
 if not index(c,'ledgeTiles')[tile] then return s end
 if (s.base or s.class)=='ledge' then return shape(shapes,c,'lip',tile) end
 Permissions=Permissions or require('src.world.gen2.Permissions')
 local radius=index(c,'capTiles')[tile] and 1 or 0
 for _,d in ipairs(dirs)do for cross=-radius,radius do
  local x=cx+d[1]+(d[2]~=0 and cross or 0)
  local y=cy+d[2]+(d[1]~=0 and cross or 0)
  local facings=Permissions.ledgeFacings(map:cellCollision(x,y))
  if facings and facings[d[3]] then return shape(shapes,c,'lip',tile) end
 end end
 return s
end
return E
