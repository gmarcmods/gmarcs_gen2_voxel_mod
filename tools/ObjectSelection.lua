-- One spatial selection shared by the map and source atlas panels.
local Selection={}
Selection.__index=Selection
function Selection.new() return setmetatable({},Selection) end
function Selection:clear() self.mapId=nil; self.source=nil; self.tilesetId=nil end
local function tilesetId(map) return map.tileset and map.tileset.id end
function Selection:valid(map)
  if not map or not self.source then return false end
  if self.mapId~=map.id or self.tilesetId~=tilesetId(map) then self:clear(); return false end
  return true
end
function Selection:begin(map,x,y)
  self.mapId=map.id
  self.tilesetId=tilesetId(map)
  self.source='map'
  self.x0,self.y0,self.x1,self.y1=x,y,x,y
end
function Selection:extend(map,x,y)
  if self:valid(map) and self.source=='map' then self.x1,self.y1=x,y end
end
function Selection:beginAtlas(map,perRow,x,y)
  self:begin(map,x,y)
  self.source='atlas'
  self.perRow=perRow
end
function Selection:extendAtlas(map,perRow,x,y)
  if self:valid(map) and self.source=='atlas' and self.perRow==perRow then self.x1,self.y1=x,y end
end
function Selection:bounds(map)
  if not self:valid(map) then return nil end
  local x,y=math.min(self.x0,self.x1),math.min(self.y0,self.y1)
  return x,y,math.abs(self.x1-self.x0)+1,math.abs(self.y1-self.y0)+1
end
function Selection:tiles(map)
  local x,y,w,h=self:bounds(map)
  if not x then return nil end
  local tiles={}
  for row=0,h-1 do
    tiles[row+1]={}
    for col=0,w-1 do
      if self.source=='atlas' then tiles[row+1][col+1]=(y+row)*self.perRow+x+col
      else tiles[row+1][col+1]=map:tileAt(x+col,y+row) end
    end
  end
  return tiles
end
function Selection:ids(map)
  local ids={}
  for _,row in ipairs(self:tiles(map) or {}) do
    for _,id in ipairs(row) do ids[id]=true end
  end
  return ids
end
local function equal(a,b)
  if not a or not b or #a~=#b then return false end
  for r,row in ipairs(a) do
    if not b[r] or #row~=#b[r] then return false end
    for c,id in ipairs(row) do if b[r][c]~=id then return false end end
  end
  return #a>0 and #a[1]>0
end
local function placements(map,tiles)
  local found={}
  local def=map and map.def
  if not def or type(def.width)~='number' or type(def.height)~='number' or not map.tileAt
    or not tiles or not tiles[1] or #tiles[1]==0 then return found end
  local w,h=#tiles[1],#tiles
  for y=0,def.height*4-h do
    for x=0,def.width*4-w do
      local matches=true
      for r,row in ipairs(tiles) do
        for c,id in ipairs(row) do
          if map:tileAt(x+c-1,y+r-1)~=id then matches=false; break end
        end
        if not matches then break end
      end
      if matches then found[#found+1]={x=x,y=y,w=w,h=h} end
    end
  end
  return found
end
function Selection:matches(map) return placements(map,self:tiles(map)) end
Selection.placements=placements
function Selection:asset(map,list)
  local tiles=self:tiles(map)
  if not tiles then return nil end
  for index,asset in ipairs(list or {}) do
    if equal(tiles,asset.tiles) then return asset,index end
  end
  if self.source~='map' then return nil end
  local x,y,w,h=self:bounds(map)
  for index,asset in ipairs(list or {}) do
    for _,p in ipairs(placements(map,asset.tiles)) do
      if x>=p.x and y>=p.y and x+w<=p.x+p.w and y+h<=p.y+p.h then return asset,index,p end
    end
  end
end
return Selection
