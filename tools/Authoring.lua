-- Safe, non-UI profile authoring for agents and batch tooling.
local source = debug.getinfo(1, "S").source or ""
local file = source:sub(1, 1) == "@" and source:sub(2) or nil
local root = file and file:match("^(.*)/tools/[^/]+$") or "."
local Model = dofile(root .. "/tools/EditorModel.lua")
local Surface = dofile(root .. "/lib/AssetSurface.lua")
local Manager = dofile(root .. "/tools/ModManager.lua")

local Authoring = {}

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for k, v in pairs(value) do out[copy(k, seen)] = copy(v, seen) end
  return out
end

local function list(value, label)
  if type(value) ~= "table" then return nil, label .. " must be a list" end
  local n = 0
  for k in pairs(value) do
    if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then
      return nil, label .. " must be a list"
    end
    n = math.max(n, k)
  end
  for i = 1, n do
    if value[i] == nil then return nil, label .. " must be a list" end
  end
  return n
end

local function validTileGrid(asset, label)
  local tiles = asset.tiles
  local rows, err = list(tiles, label .. ".tiles")
  if not rows or rows == 0 then return false, label .. " needs a tile grid" end
  if rows > 32 then return false, label .. " tile grid is taller than 32 rows" end
  local width
  for y = 1, rows do
    local row, rowErr = list(tiles[y], label .. ".tiles[" .. y .. "]")
    if not row or row == 0 then return false, label .. " needs a tile grid" end
    if row > 32 then return false, label .. " tile grid is wider than 32 columns" end
    width = width or row
    if row ~= width then return false, label .. " has an uneven tile grid" end
    for x = 1, row do
      local id = tiles[y][x]
      if type(id) ~= "number" or id ~= id or id == math.huge
         or id == -math.huge or id ~= math.floor(id) or id < 0 then
        return false, label .. " has an invalid tile id" end
    end
  end
  return true
end

local function validateAsset(asset, label)
  if type(asset) ~= "table" then return false, label .. " must be a table" end
  if type(asset.id) ~= "string" or asset.id == "" then
    return false, label .. " needs a non-empty id"
  end
  if asset.map ~= nil and (type(asset.map) ~= "string" or asset.map == "") then
    return false, label .. ".map must be a non-empty map id"
  end
  if asset.groundTile~=nil and(type(asset.groundTile)~='number'or asset.groundTile~=asset.groundTile or asset.groundTile<0 or asset.groundTile%1~=0)then
    return false,label..'.groundTile must be a tile id'
  end
  local ok, err = validTileGrid(asset, label)
  if not ok then return false, err end
  if asset.topRows ~= nil then
    local valid, why = validTileGrid({tiles=asset.topRows}, label .. ".topRows")
    if not valid then return false, why end
    if #asset.topRows[1] ~= #asset.tiles[1] then
      return false, label .. ".topRows must have the same width as tiles"
    end
  end
  -- Existing runtime claim templates suppress a projected fragment whose
  -- actual geometry belongs to the connected map. No surfaces means the
  -- editor will not offer an empty model as an editable asset.
  if asset.claimOnly == true and asset.surfaces == nil and asset.voxelEdits == nil then return true end
  if type(asset.surfaces) ~= "table" then
    return false, label .. " needs surfaces" end
  local surfaceCount, surfaceErr = list(asset.surfaces, label .. ".surfaces")
  if not surfaceCount or surfaceCount == 0 then
    return false, label .. " needs surfaces"
  end
  local width = #asset.tiles[1] * 8
  local height = (#asset.tiles + #(asset.topRows or {})) * 8
  local built, buildErr = pcall(Surface.build, width, height,
    asset.surfaces, asset.voxelEdits)
  if not built then return false, label .. " has invalid surfaces: " .. tostring(buildErr) end
  return true
end

local function sortedKeys(tbl)
  local keys = {}
  for key in pairs(tbl) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  return keys
end

local function validateAssetList(existing, incoming, tset)
  local seen = {}
  for i, asset in ipairs(existing or {}) do
    if type(asset) == "table" and asset.id ~= nil then
      if seen[asset.id] then return nil, "duplicate asset id: " .. tostring(asset.id) end
      seen[asset.id] = true
    end
  end
  local incomingIDs = {}
  for i, asset in ipairs(incoming or {}) do
    local ok, err = validateAsset(asset, "tileset " .. tset .. " asset " .. i)
    if not ok then return nil, err end
    if incomingIDs[asset.id] then
      return nil, "duplicate asset id: " .. asset.id
    end
    incomingIDs[asset.id] = true
  end
  return incomingIDs
end

-- Apply a batch to a profile in memory. The input profile and batch are never changed.
function Authoring.apply(profile, batch)
  if type(profile) ~= "table" then return nil, "profile must be a table" end
  if type(batch) ~= "table" or type(batch.tilesets) ~= "table" then
    return nil, "batch.tilesets must be a table" end
  local result = copy(profile)
  result.tilesets = result.tilesets or {}
  result.buildings = result.buildings or {}
  local model = Model.new(result)
  local counts = {assets = 0, classes = 0, pins = 0, heights = 0}

  for _, tset in ipairs(sortedKeys(batch.tilesets)) do
    local change = batch.tilesets[tset]
    if type(tset) ~= "string" or type(change) ~= "table" then
      return nil, "tileset changes must be tables" end
    local oldTileset = result.tilesets[tset] or {}
    if type(oldTileset) ~= "table" then return nil, "invalid tileset: " .. tset end
    local incoming = change.assets or {}
    local n, listErr = list(incoming, "tileset " .. tset .. ".assets")
    if not n then return nil, listErr end
    local incomingIDs, assetErr = validateAssetList(result.buildings[tset], incoming, tset)
    if not incomingIDs then return nil, assetErr end
    if n > 0 then
      local merged = {}
      for i = 1, n do merged[#merged + 1] = copy(incoming[i]) end
      for _, old in ipairs(result.buildings[tset] or {}) do
        if not incomingIDs[old.id] then merged[#merged + 1] = old end
      end
      result.buildings[tset] = merged
      counts.assets = counts.assets + n
      model = Model.new(result)
    end

    if change.classes ~= nil then
      if type(change.classes) ~= "table" then return nil, "classes must be a table" end
      for _, className in ipairs(sortedKeys(change.classes)) do
        local definition = change.classes[className]
        local current = result.classes and result.classes[className]
        local ok, err
        if current ~= nil then
          ok, err = model:editClass(className, className, copy(definition))
        else
          ok, err = model:defineClass(className, copy(definition))
        end
        if not ok then return nil, "class " .. tostring(className) .. ": " .. tostring(err) end
        result = model:fuse()
        model = Model.new(result)
        counts.classes = counts.classes + 1
      end
    end

    if change.pins ~= nil then
      if type(change.pins) ~= "table" then return nil, "pins must be a table" end
      for _, className in ipairs(sortedKeys(change.pins)) do
        local pin = change.pins[className]
        if type(pin) ~= "table" then return nil, "pins for " .. tostring(className) .. " must be a table" end
        local known = Model.isClass(className) or (result.classes and result.classes[className] ~= nil)
        if not known then return nil, "unknown class: " .. tostring(className) end
        local tileIDs = pin.tileIDs
        if tileIDs == nil then
          tileIDs = pin
        end
        local ids, idsErr = list(tileIDs, "pins for " .. tostring(className) .. ".tileIDs")
        if not ids then return nil, idsErr end
        local seen = {}
        for i = 1, ids do
          local id = tileIDs[i]
          if type(id) ~= "number" or id ~= id or id == math.huge
             or id == -math.huge or id ~= math.floor(id) or id < 0 then
            return nil, "invalid tile id in pins for " .. className end
          if seen[id] then return nil, "duplicate pinned tile id: " .. tostring(id) end
          seen[id] = true
          model:push({op = "set_class", tset = tset, class = className, tile = id})
          counts.pins = counts.pins + 1
        end
      end
    end
    local function tileID(id)
      return type(id)=='number' and id==id and id<math.huge and id>=0 and id%1==0
    end
    for _,field in ipairs({'when_above','when_below'}) do
      if change[field] then
        if type(change[field])~='table' then return nil,field..' must be a table' end
        local side=field=='when_above' and 'above' or 'below'
        for tile,rules in pairs(change[field]) do
          if not tileID(tile) or not list(rules,field) then return nil,'invalid contextual tile/rules' end
          for _,rule in ipairs(rules) do
            if type(rule)~='table' or not (Model.isClass(rule.class) or result.classes and result.classes[rule.class]) then
              return nil,'unknown contextual class'
            end
            if not list(rule[side],side) then return nil,'invalid contextual neighbours' end
            for _,id in ipairs(rule[side]) do if not tileID(id) then return nil,'invalid contextual neighbour tile' end end
          end
          model:push({op=field,tset=tset,tile=tile,rules=copy(rules)})
        end
      end
    end
    if change.border_blocks~=nil then
      if type(change.border_blocks)~='table' then return nil,'border_blocks must be a map' end
      for mapID,block in pairs(change.border_blocks) do
        if type(mapID)~='string' or mapID=='' or
          (block~=false and (type(block)~='number' or block~=block or block%1~=0 or block<0 or block>255)) then
          return nil,'invalid map border block'
        end
      end
      model:push({op='border_blocks',tset=tset,value=copy(change.border_blocks)})
    end
    if change.terrain_edges~=nil then
      local ok,err=dofile(root.."/lib/TerrainEdges.lua").validate(change.terrain_edges)
      if not ok then return nil,err end
      local shore=change.terrain_edges.shoreClass
      if not (Model.isClass(shore) or result.classes and result.classes[shore]) then
        return nil,"unknown terrain shore class"
      end
      model:push({op="terrain_edges",tset=tset,value=copy(change.terrain_edges)})
    end
    if change.mountain~=nil then
      local ok,err=dofile(root.."/lib/MountainShape.lua").validate(change.mountain)
      if not ok then return nil,err end
      for _,name in ipairs(change.mountain.classes) do
        if not (result.classes and result.classes[name]) and not Model.isClass(name) then return nil,"unknown mountain class" end
      end
      model:push({op="mountain",tset=tset,value=copy(change.mountain)})
    end
    if change.planter_spray~=nil then
      if type(change.planter_spray)~='boolean' then return nil,'planter_spray must be boolean' end
      model:push({op='spray',tset=tset,value=change.planter_spray})
    end
    if change.prop_ground then
      if type(change.prop_ground)~='table' then return nil,'prop_ground must be a table' end
      for tile,ground in pairs(change.prop_ground) do
        if not tileID(tile) or not tileID(ground) then return nil,'invalid prop ground tile' end
        model:push({op='prop_ground',tset=tset,tile=tile,ground=ground})
      end
    end
    if change.heights~=nil then
      if type(change.heights)~='table' then return nil,'heights must be a table' end
      for class,height in pairs(change.heights) do
        if not Model.isClass(class) then return nil,'unknown height class: '..tostring(class) end
        if type(height)~='number' or height~=height or height==math.huge or height==-math.huge then
          return nil,'invalid height for '..tostring(class)
        end
      end
    end
    result = model:fuse()
    if change.heights then
      local heights=result.tilesets[tset].heights or {}
      for class,height in pairs(change.heights) do heights[class]=height;counts.heights=counts.heights+1 end
      result.tilesets[tset].heights=heights
    end
    model = Model.new(result)
  end
  local valid, validationErr = model:validateClasses(result)
  if not valid then return nil, "invalid classes: " .. tostring(validationErr) end
  return result, counts
end

local function read(path)
  local f, err = io.open(path, "rb")
  if not f then return nil, err end
  local data = f:read("*a")
  f:close()
  return data
end

local backupCounter = 0
local function backup(path, bytes)
  local stamp = os.date("%Y%m%d-%H%M%S")
  for _ = 1, 100 do
    backupCounter = backupCounter + 1
    local target = path .. ".bak." .. stamp .. "." .. backupCounter
    local f = io.open(target, "wx")
    if f then
      local ok, err = f:write(bytes)
      local closed = f:close()
      if not ok or closed == false then os.remove(target); return nil, err or "backup close failed" end
      return target
    end
  end
  return nil, "could not create unique backup"
end

-- Reload, validate, back up, and atomically install a batch in a project.
function Authoring.install(project, batch)
  if type(project) ~= "string" or project == "" then return nil, "project path is required" end
  local projectPath = Manager.absolutePath(project)
  local profilePath = projectPath .. "/data/voxel_heights.lua"
  local original, readErr = read(profilePath)
  if not original then return nil, "cannot read profile: " .. tostring(readErr) end
  local profile, err = Manager.loadProfile(projectPath)
  if not profile then return nil, err end
  local loadedBytes, loadedReadErr = read(profilePath)
  if not loadedBytes then return nil, "cannot re-read profile: " .. tostring(loadedReadErr) end
  if loadedBytes ~= original then
    return nil, "profile changed while loading; refusing to overwrite"
  end
  local staged, counts = Authoring.apply(profile, batch)
  if not staged then return nil, counts end
  local current, currentErr = read(profilePath)
  if not current then return nil, "cannot re-read profile: " .. tostring(currentErr) end
  if current ~= original then return nil, "profile changed during authoring; refusing to overwrite" end
  local backupPath, backupErr = backup(profilePath, original)
  if not backupPath then return nil, backupErr end
  current, currentErr = read(profilePath)
  if not current then os.remove(backupPath); return nil, "cannot re-read profile: " .. tostring(currentErr) end
  if current ~= original then
    os.remove(backupPath)
    return nil, "profile changed before save; refusing to overwrite"
  end
  local saved, saveErr = Manager.saveProfile(projectPath, staged)
  if not saved then os.remove(backupPath); return nil, saveErr end
  return {
    project = projectPath, profile = profilePath, backup = backupPath,
    assets = counts.assets, classes = counts.classes, pins = counts.pins,
    counts = copy(counts), paths = {project = projectPath, profile = profilePath,
      backup = backupPath},
  }
end

return Authoring
