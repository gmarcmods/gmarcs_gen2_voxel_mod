-- ROUTE_39's north-south Moomoo Farm fence uses connected tile-74 cells.
-- Replace the per-pixel standees only for those cells; all ownership and
-- collision bookkeeping remains with Structures.
local FenceRails = {}

local function appendBox(out, x0, x1, y0, y1, z0, z1, uv, dims)
  local u, v = uv[1] / dims[1], uv[2] / dims[2]
  local function face(points, shade)
    out[#out + 1] = {
      points[1], points[2], points[3], points[4],
      u=u, v=v, shade=shade,
    }
  end
  face({{x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1}}, .95) -- top
  face({{x0,y0,z1},{x1,y0,z1},{x1,y1,z1},{x0,y1,z1}}, .9) -- south
  face({{x1,y0,z0},{x0,y0,z0},{x0,y1,z0},{x1,y1,z0}}, .7) -- north
  face({{x0,y0,z0},{x0,y0,z1},{x0,y1,z1},{x0,y1,z0}}, .78)
  face({{x1,y0,z1},{x1,y0,z0},{x1,y1,z0},{x1,y1,z1}}, .78)
  face({{x0,y0,z0},{x1,y0,z0},{x1,y0,z1},{x0,y0,z1}}, .78)
end

function FenceRails.buildCell(S, map, reg, keyOf, firstQuad)
  if not map or map.id ~= "ROUTE_39" or not reg or not reg.tiles then return false end
  local cx, cy = math.floor(reg.minX / 2), math.floor(reg.minY / 2)
  local touches74 = false
  for _, tile in ipairs(reg.tiles) do
    if map:tileAt(tile[1], tile[2]) == 74 then touches74 = true; break end
  end
  if not touches74 then return false end
  local adjacent = false
  for _, dy in ipairs({-1, 1}) do
    for dx = 0, 1 do
      for dyTile = 0, 1 do
        if map:tileAt(cx * 2 + dx, (cy + dy) * 2 + dyTile) == 74 then adjacent = true end
      end
    end
  end
  if not adjacent then return false end

  local target = S.objectQuads
  if not target or type(firstQuad) ~= "number" then return false end
  local atlas = map.tileset or {}
  local width, height = atlas.imageWidth or 128, atlas.imageHeight or 128
  local perRow = atlas.perRow or atlas.tilesPerRow or 16
  local tileX, tileY = 74 % perRow, math.floor(74 / perRow)
  local function donor(x, y) return tileX * 8 + x, tileY * 8 + y end
  local railUV = {donor(2.5, 3.5)}
  local postUV = {donor(2.5, 1.5)}
  local outlineUV = {donor(1.5, 1.5)}
  local x = reg.minX * 8 + 3
  local z = math.floor(reg.minY / 2) * 16 + 8
  local replacement = {}
  -- Native fence posts have a dark one-pixel rim and a light face. Keep
  -- that outline as actual adjoining voxel strips, not coplanar decals.
  appendBox(replacement,x-2,x-1,0,16,z-2,z+2,outlineUV,{width,height})
  appendBox(replacement,x+2,x+3,0,16,z-2,z+2,outlineUV,{width,height})
  appendBox(replacement,x-1,x+2,0,1,z-2,z+2,outlineUV,{width,height})
  appendBox(replacement,x-1,x+2,15,16,z-2,z+2,outlineUV,{width,height})
  appendBox(replacement,x-1,x+2,1,15,z-2,z+2,postUV,{width,height})
  appendBox(replacement, x - 1, x + 1, 5, 7, z - 8, z + 8, railUV, {width,height})
  appendBox(replacement, x - 1, x + 1, 11, 13, z - 8, z + 8, railUV, {width,height})
  if #replacement > 42 then return false end
  for i = #target, firstQuad + 1, -1 do target[i] = nil end
  for _, q in ipairs(replacement) do target[#target + 1] = q end
  return true
end

return FenceRails
