-- ZoneOverlay: renders zone overlays on q3 (tileset) and q2 (map).
-- Factory pattern: pass dependencies at creation time.
--
-- Usage in editor.lua:
--   local ZoneOverlay = dofile(V.mod.path .. "/tools/ZoneOverlay.lua")(
--     TileShape, ZoneColors, ZoneResolve
--   )

return function(TileShape, ZoneColors, ZoneResolve)
  local ZoneOverlay = {}
  local G = love.graphics

  -- Dash pattern for borders: segment length in pixels (before scale)
  local DASH_LEN = 6
  local GAP_LEN = 4
  local BORDER_THICKNESS = 2

  -- Draw a dashed horizontal line
  local function dashH(x1, x2, y, zoom)
    local step = (DASH_LEN + GAP_LEN) * zoom
    local seg = DASH_LEN * zoom
    local pos = x1
    while pos < x2 do
      local finish = math.min(pos + seg, x2)
      G.line(pos, y, finish, y)
      pos = pos + step
    end
  end

  -- Draw a dashed vertical line
  local function dashV(x, y1, y2, zoom)
    local step = (DASH_LEN + GAP_LEN) * zoom
    local seg = DASH_LEN * zoom
    local pos = y1
    while pos < y2 do
      local finish = math.min(pos + seg, y2)
      G.line(x, pos, x, finish)
      pos = pos + step
    end
  end

  -- Draw zone overlay on the tileset atlas (q3).
  --
  -- Parameters:
  --   spec       - fused profile (from model:fuse())
  --   tsetId     - current tileset id string
  --   shapes     - TileShape.forMap(map) result (per-tiletype resolution)
  --   dx, dy     - top-left of the atlas image on screen (scaled)
  --   zoom       - scale factor (pixels per atlas pixel)
  --   tilesW     - atlas width in tiles
  --   tilesH     - atlas height in tiles
  function ZoneOverlay.drawTileset(spec, tsetId, shapes, dx, dy, zoom, tilesW, tilesH)
    if not shapes or not tsetId then return end

    local cellPx = 8 * zoom
    if cellPx < 2 then return end  -- too small to see

    -- Phase 1: filled rects (class coloring)
    for ty = 0, tilesH - 1 do
      for tx = 0, tilesW - 1 do
        local tileId = ty * tilesW + tx
        local class = ZoneResolve.forTileType(shapes, tileId) or "wall"
        local pinned = ZoneResolve.isPinned(spec, tsetId, tileId)
        local r, g, b = unpack(ZoneColors.get(class, pinned))
        local alpha = pinned and ZoneColors.PAINTED_ALPHA or ZoneColors.AUTO_ALPHA

        G.setColor(r, g, b, alpha)
        G.rectangle("fill",
          dx + tx * cellPx,
          dy + ty * cellPx,
          cellPx, cellPx)
      end
    end

    -- Phase 2: dashed borders (only if cells are big enough to see)
    if cellPx < 6 then return end

    local br, bg, bb = unpack(ZoneColors.BORDER)
    G.setColor(br, bg, bb, 0.85)
    G.setLineWidth(BORDER_THICKNESS)

    for ty = 0, tilesH - 1 do
      for tx = 0, tilesW - 1 do
        local tileId = ty * tilesW + tx
        local class = ZoneResolve.forTileType(shapes, tileId) or "wall"

        -- Right border
        if tx < tilesW - 1 then
          local rightId = ty * tilesW + (tx + 1)
          local rightClass = ZoneResolve.forTileType(shapes, rightId) or "wall"
          if class ~= rightClass then
            local bx = dx + (tx + 1) * cellPx
            dashH(bx - 3, bx + 3, dy + ty * cellPx, zoom)
          end
        end

        -- Bottom border
        if ty < tilesH - 1 then
          local belowId = (ty + 1) * tilesW + tx
          local belowClass = ZoneResolve.forTileType(shapes, belowId) or "wall"
          if class ~= belowClass then
            local by = dy + (ty + 1) * cellPx
            dashV(dx + tx * cellPx, by - 3, by + 3, zoom)
          end
        end
      end
    end
  end

  -- Draw zone overlay on the map (q2).
  --
  -- Parameters:
  --   spec       - fused profile
  --   map        - game map object
  --   shapes     - TileShape.forMap(map) result
  --   dx, dy     - top-left of the map image on screen (scaled)
  --   zoom       - scale factor (pixels per atlas pixel)
  --   mapW       - map width in tiles
  --   mapH       - map height in tiles
  function ZoneOverlay.drawMap(spec, map, shapes, dx, dy, zoom, mapW, mapH)
    if not shapes or not map then return end

    local cellPx = 8 * zoom
    if cellPx < 2 then return end

    local tsetId = map.tileset and map.tileset.id

    -- Phase 1: filled rects
    for ty = 0, mapW - 1 do
      for y = 0, mapH - 1 do
        local tile = map:tileAt(ty, y)
        local res = ZoneResolve.at(map, shapes, tile, ty, y)
        local class = res.class or "wall"
        local pinned = tsetId and ZoneResolve.isPinned(spec, tsetId, tile) or false
        local r, g, b = unpack(ZoneColors.get(class, pinned))
        local alpha = pinned and ZoneColors.PAINTED_ALPHA or ZoneColors.AUTO_ALPHA

        G.setColor(r, g, b, alpha)
        G.rectangle("fill",
          dx + ty * cellPx,
          dy + y * cellPx,
          cellPx, cellPx)
      end
    end

    -- Phase 2: dashed borders
    if cellPx < 6 then return end

    local br, bg, bb = unpack(ZoneColors.BORDER)
    G.setColor(br, bg, bb, 0.85)
    G.setLineWidth(BORDER_THICKNESS)

    -- Cache resolved classes for border detection
    local classCache = {}
    local function getClass(tx, y)
      local key = tx .. "," .. y
      if not classCache[key] then
        local tile = map:tileAt(tx, y)
        local res = ZoneResolve.at(map, shapes, tile, tx, y)
        classCache[key] = res.class or "wall"
      end
      return classCache[key]
    end

    for ty = 0, mapW - 1 do
      for y = 0, mapH - 1 do
        local class = getClass(ty, y)

        -- Right border
        if ty < mapW - 1 then
          local rightClass = getClass(ty + 1, y)
          if class ~= rightClass then
            local bx = dx + (ty + 1) * cellPx
            dashH(bx - 2, bx + 2, dy + y * cellPx, zoom)
          end
        end

        -- Bottom border
        if y < mapH - 1 then
          local belowClass = getClass(ty, y + 1)
          if class ~= belowClass then
            local by = dy + (y + 1) * cellPx
            dashV(dx + ty * cellPx, by - 2, by + 2, zoom)
          end
        end
      end
    end
  end

  return ZoneOverlay
end
