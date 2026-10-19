-- Zone resolution API for the voxel editor.
--
-- Wraps TileShape.at / TileShape.forMap into simple queries that the
-- overlay renderer and the inspect panel can call every frame.
--
-- Factory pattern: create with dofile(...)(TileShape)

return function(TileShape)
  local ZoneResolve = {}

  -- Resolve a tile TYPE (no position context — no cell predicates).
  -- Returns the class string from TileShape.forMap shapes.
  function ZoneResolve.forTileType(shapes, tileId)
    if not shapes then return "wall" end
    local shape = shapes[tileId]
    if not shape then return "wall" end
    return shape.class or "wall"
  end

  -- Check whether a tile is pinned (authored) in the spec for a tileset.
  -- spec = fused profile from model:fuse()
  function ZoneResolve.isPinned(spec, tsetId, tileId)
    if not spec or not spec.tilesets or not tsetId then return false end
    local ts = spec.tilesets[tsetId]
    if not ts then return false end
    for class, tiles in pairs(ts) do
      if type(tiles) == "table" then
        for _, id in ipairs(tiles) do
          if id == tileId then return true end
        end
      end
    end
    return false
  end

  -- Resolve a single tile position on the current map.
  -- Returns { class, source, height, art, isPainted }.
  function ZoneResolve.at(map, shapes, tile, tx, ty)
    if not map or not shapes then
      return { class = "wall", source = "auto", height = 16,
               art = "upright", isPainted = false }
    end
    local ok, shape = pcall(TileShape.at, map, shapes, tile, tx, ty)
    if not ok or not shape then
      return { class = "wall", source = "auto", height = 16,
               art = "upright", isPainted = false }
    end
    return {
      class   = shape.class  or "wall",
      source  = shape.authored and "painted" or "auto",
      height  = shape.h      or 16,
      art     = shape.art    or "upright",
      isPainted = not not shape.authored,
    }
  end

  return ZoneResolve
end
