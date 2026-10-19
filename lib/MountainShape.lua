-- Opt-in terrain height field. Canonical tile classes and walkable ground
-- remain unchanged; only listed rock classes climb away from exposed edges.
local M={}
local V=...
local Budget=V and V.require('BuildBudget')
local world
-- Resolve only the maps touched by a bounded height-field halo. This keeps
-- the field independent of which side of a connection owns the camera.
function M.bind(maps,tilesets,makeMap,forMap)
 if world and world.maps==maps then return end
 world={maps=maps,tilesets=tilesets,make=makeMap,shapes=forMap,instances=setmetatable({},{__mode='v'})}
end
local function namesFor(shapes)
 if not shapes.mountainNames then
  local names={};for _,v in ipairs(shapes.mountain.classes)do names[v]=true end
  shapes.mountainNames=names
 end
 return shapes.mountainNames
end
local function sample(map,shapes,x,y,raw,depth)
 local W,H=map.def.width*4,map.def.height*4
 if x>=0 and y>=0 and x<W and y<H then
  local s=raw(map,shapes,map:tileAt(x,y),x,y)
  return s,map,shapes,x,y
 end
 if not world or depth>=8 then return nil end
 for dir,conn in pairs(map.def.connections or {})do
  local id=conn.mapId or conn.map;local def=world.maps[id]
  if def then
   local off=(conn.offset or 0)*4;local ox,oy
   if dir=='east' then ox,oy=W,off
   elseif dir=='west' then ox,oy=-def.width*4,off
   elseif dir=='south' then ox,oy=off,H
   elseif dir=='north' then ox,oy=off,-def.height*4 end
   local crosses=(dir=='east' and x>=W and y>=oy and y<oy+def.height*4)
    or (dir=='west' and x<0 and y>=oy and y<oy+def.height*4)
    or (dir=='south' and y>=H and x>=ox and x<ox+def.width*4)
    or (dir=='north' and y<0 and x>=ox and x<ox+def.width*4)
   if crosses then
    local other=world.instances[id]
    if not other then other=world.make(def,world.tilesets[def.tileset]);world.instances[id]=other end
    return sample(other,world.shapes(other),x-ox,y-oy,raw,depth+1)
   end
  end
 end
end
function M.validate(c)
 if type(c)~='table' or type(c.classes)~='table' or #c.classes==0 then return false,'mountain classes required' end
 for _,v in ipairs(c.classes) do if type(v)~='string' then return false,'invalid mountain class' end end
 for _,k in ipairs({'rise','maxHeight','sideTile'}) do
  local v=c[k];if type(v)~='number' or v~=v or v%1~=0 or v<0 or v>255 then return false,'invalid mountain '..k end
 end
 if c.topTile~=nil and(type(c.topTile)~='number'or c.topTile~=c.topTile or c.topTile%1~=0 or c.topTile<0 or c.topTile>255)then return false,'invalid mountain topTile'end
 if c.rise<1 or c.maxHeight>128 then return false,'mountain height out of range' end
 return true
end
function M.at(map,shapes,s,tx,ty,raw)
 local c=shapes.mountain
 if not c or not s then return s end
 local W,H=map.def.width*4,map.def.height*4
 if tx<0 or ty<0 or tx>=W or ty>=H then
  local ns,other,os,x,y=sample(map,shapes,tx,ty,raw,0)
  if other then return M.at(other,os,ns,x,y,raw) end
  return s
 end
 local names=namesFor(shapes)
 if not names[s.class] then return s end
 local cache=shapes.mountainMaps
 if not cache then cache=setmetatable({},{__mode='k'});shapes.mountainMaps=cache end
 local field=cache[map]
 if not field then
  field={};local cells,queue={},{}
  -- A halo as wide as the largest unsaturated rise makes independently
  -- meshed adjoining maps produce the same heights at their shared edge.
  local r=world and math.ceil(c.maxHeight/c.rise)+1 or 0
  local stride=W+2*r;local height=H+2*r
  for y=0,height-1 do
   if Budget then Budget.tick() end
   for x=0,stride-1 do
    local shape,_,owner=sample(map,shapes,x-r,y-r,raw,0)
    if shape and owner.mountain and namesFor(owner)[shape.class] then cells[y*stride+x]=shape end
   end
  end
  for k in pairs(cells) do
   local x,y=k%stride,math.floor(k/stride)
   if x==0 or y==0 or x==stride-1 or y==height-1 or not cells[k-1] or not cells[k+1] or not cells[k-stride] or not cells[k+stride] then
    field[k]=0;queue[#queue+1]=k
   end
  end
  local head=1
  while head<=#queue do
   local k=queue[head];head=head+1;local x=k%stride
   for _,n in ipairs({x>0 and k-1 or -1,x<stride-1 and k+1 or -1,k-stride,k+stride}) do
    if cells[n] and field[n]==nil then field[n]=field[k]+1;queue[#queue+1]=n end
   end
  end
  local resolved={}
  for k,base in pairs(cells) do
   local x,y=k%stride-r,math.floor(k/stride)-r
   if x>=0 and y>=0 and x<W and y<H then
    local copy={};for name,value in pairs(base) do copy[name]=value end
    copy.h=math.max(base.h,math.min(c.maxHeight,base.h+(field[k] or 0)*c.rise))
    copy.sideTile=c.sideTile;copy.topTile=c.topTile or copy.topTile;resolved[y*W+x]=copy
   end
  end
  field=resolved
  cache[map]=field
 end
 return field[ty*W+tx] or s
end
return M
