-- AutoScanner: discover tilesets/maps and suggest starting profiles.
--
-- Scans the live game world to find all tilesets, which maps use them,
-- and which tilesets have no profile data yet (need work).

local AutoScanner = {}

-- Discover all tilesets and which maps use them.
-- world: game.world (has .tilesets, .maps tables).
-- Returns: { tilesets = { {id, mapCount, maps}, ... },
--            maps = { mapId -> tilesetId } }
function AutoScanner.scanTilesets(world)
  local tilesetMaps = {}   -- tsetId -> { mapId, ... }
  local mapToTileset = {}  -- mapId -> tsetId

  for mapId, def in pairs(world.maps or {}) do
    if type(def) == "table" and type(def.tileset) == "string" then
      local tsId = def.tileset
      tilesetMaps[tsId] = tilesetMaps[tsId] or {}
      tilesetMaps[tsId][#tilesetMaps[tsId] + 1] = mapId
      mapToTileset[mapId] = tsId
    end
  end

  local result = { tilesets = {}, maps = mapToTileset }
  local ids = {}
  for tsId in pairs(tilesetMaps) do ids[#ids + 1] = tsId end
  table.sort(ids)
  for _, tsId in ipairs(ids) do
    local maps = tilesetMaps[tsId]
    table.sort(maps)
    result.tilesets[#result.tilesets + 1] = {
      id = tsId,
      mapCount = #maps,
      maps = maps,
      def = world.tilesets and world.tilesets[tsId],
    }
  end
  return result
end

-- Generate a minimal starting profile from discovered tilesets.
-- For each tileset, adds an empty entry (TileShape derives defaults).
-- Returns: profile table.
function AutoScanner.suggestProfile(scanResult, existingProfile)
  local profile = existingProfile or {
    version = 1, heights = {}, tilesets = {}, buildings = {},
  }
  profile.heights = profile.heights or {}
  profile.tilesets = profile.tilesets or {}
  profile.buildings = profile.buildings or {}

  for _, ts in ipairs(scanResult.tilesets) do
    if not profile.tilesets[ts.id] then
      profile.tilesets[ts.id] = {}
    end
  end
  return profile
end

-- Find tilesets that have no tiles pinned (no user work yet).
-- Returns: { {id, mapCount, maps}, ... } sorted by mapCount descending.
function AutoScanner.identifyUnprofiledTilesets(profile, scanResult)
  local unprofiled = {}
  for _, ts in ipairs(scanResult.tilesets) do
    local tsData = profile.tilesets and profile.tilesets[ts.id]
    local hasContent = false
    if tsData then
      for k, v in pairs(tsData) do
        if type(v) == "table" and #v > 0 then
          hasContent = true; break
        end
      end
    end
    if not hasContent then
      unprofiled[#unprofiled + 1] = {
        id = ts.id,
        mapCount = ts.mapCount,
        maps = ts.maps,
      }
    end
  end
  table.sort(unprofiled, function(a, b) return a.mapCount > b.mapCount end)
  return unprofiled
end

-- Find tilesets that have some content (partial or complete profile).
-- Returns: { {id, mapCount, pinnedClasses}, ... }
function AutoScanner.identifyProfiledTilesets(profile, scanResult)
  local profiled = {}
  for _, ts in ipairs(scanResult.tilesets) do
    local tsData = profile.tilesets and profile.tilesets[ts.id]
    local pinnedClasses = 0
    if tsData then
      for k, v in pairs(tsData) do
        if type(v) == "table" and #v > 0 then
          pinnedClasses = pinnedClasses + 1
        end
      end
    end
    if pinnedClasses > 0 then
      profiled[#profiled + 1] = {
        id = ts.id,
        mapCount = ts.mapCount,
        pinnedClasses = pinnedClasses,
      }
    end
  end
  table.sort(profiled, function(a, b) return a.id < b.id end)
  return profiled
end

-- Get a summary string for display.
-- Returns: "N tilesets, M profiled, K need work"
function AutoScanner.summary(profile, scanResult)
  local total = #scanResult.tilesets
  local profiled = #AutoScanner.identifyProfiledTilesets(profile, scanResult)
  local unprofiled = total - profiled
  return ("%d tilesets, %d profiled, %d need work"):format(
    total, profiled, unprofiled)
end

-- Find the first unprofiled tileset (sorted by map count).
-- Useful for auto-navigating to where work is needed.
-- Returns: tilesetId or nil.
function AutoScanner.nextUnprofiledTileset(profile, scanResult)
  local unprofiled = AutoScanner.identifyUnprofiledTilesets(profile, scanResult)
  return unprofiled[1] and unprofiled[1].id
end

return AutoScanner
