local root=debug.getinfo(1,'S').source:sub(2):match('(.+)/tools/') or '.'
local Selection=dofile(root..'/tools/ObjectSelection.lua')
local O={}
function O.entries(profile,map)
  local entries={}
  if not map or not map.tileset then return entries end
  for _,asset in ipairs(profile.buildings and profile.buildings[map.tileset.id] or {}) do
    if (not asset.map or asset.map==map.id) and (asset.surfaces or asset.tileShapes) then
      local ids={}
      for _,row in ipairs(asset.tiles or {}) do for _,tile in ipairs(row) do ids[tile]=true end end
      entries[#entries+1]={id=asset.id,ids=ids,placements=Selection.placements(map,asset.tiles)}
    end
  end
  return entries
end
function O.draw(entries,panel,x,y,scale,perRow)
  local G=love.graphics; local cell=8*scale
  for _,entry in ipairs(entries) do
    G.setColor(.9,.45,1,1)
    if panel=='map' then
      for _,p in ipairs(entry.placements) do
        G.rectangle('line',x+p.x*cell,y+p.y*cell,p.w*cell,p.h*cell)
        G.print(entry.id,x+p.x*cell+2,y+p.y*cell+2)
      end
    else
      for tile in pairs(entry.ids) do
        local px,py=x+tile%perRow*cell,y+math.floor(tile/perRow)*cell
        G.rectangle('line',px+1,py+1,cell-2,cell-2)
        G.rectangle('fill',px+2,py+2,math.min(4,cell-4),math.min(4,cell-4))
      end
    end
  end
end
return O
