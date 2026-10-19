local EditorModel = {}
local saveCounter = 0

local function loadClassDefinitions()
  local source = debug.getinfo(1, "S").source or ""
  local dir = source:match("^@(.*/)")
  if dir then return dofile(dir .. "../lib/ClassDefinitions.lua") end
  return require("lib.ClassDefinitions")
end

local ClassDefinitions = loadClassDefinitions()

local CLASS_ORDER = {
  "ground", "water", "void",
  "ledge", "fence", "sign",
  "wall", "cliff", "tree", "roof",
  "bed", "stool", "counter", "backrest", "table", "desk",
  "prop", "cutout", "bike", "planter", "sapling",
  "relief", "bookcase", "cylinder",
  "stair_e", "stair_w", "stair_n", "stair_down_e", "stair_down_w", "stair_down_n",
  "billboard", "console", "signpost", "post",
  "can", "stump", "canopy", "grass", "flower",
}

local CLASS_SET = {}
for _, c in ipairs(CLASS_ORDER) do CLASS_SET[c] = true end

function EditorModel.allClasses(profile)
  local classes = profile and profile.classes or nil
  local names=ClassDefinitions.names(classes, CLASS_ORDER)
  table.sort(names,function(a,b)
    if a:lower()==b:lower() then return a<b end
    return a:lower()<b:lower()
  end)
  return names
end

function EditorModel.isClass(name)
  return CLASS_SET[name] == true
end

function EditorModel:classNames(spec)
  return ClassDefinitions.names(spec and spec.classes, CLASS_ORDER)
end

function EditorModel:classMap(spec)
  local builtins = {}
  for _, name in ipairs(CLASS_ORDER) do builtins[name] = true end
  return builtins
end

function EditorModel:validateClasses(spec)
  local ok, err = ClassDefinitions.validateAll(spec.classes or {}, self:classMap(spec))
  if not ok then return false, err end
  return true
end

function EditorModel.new(profile)
  local m = {
    profile = profile or {version = 1, heights = {}, tilesets = {}, buildings = {}},
    ops = {},
    undoStack = {},
  }
  return setmetatable(m, {__index = EditorModel})
end

function EditorModel:fuse()
  local spec = self:deepcopy(self.profile)
  for _, op in ipairs(self.ops) do
    self:applyOp(spec, op)
  end
  return spec
end

-- Shared read-only view for rendering. Call fuse() when the caller will mutate.
-- Compare profile/ops identity too: sessions may replace the source wholesale.
function EditorModel:snapshot()
  if not self._snapshot or self._snapshotProfile~=self.profile
      or self._snapshotOps~=self.ops or self._snapshotCount~=#self.ops then
    self._snapshot=#self.ops==0 and self.profile or self:fuse()
    self._snapshotProfile=self.profile
    self._snapshotOps=self.ops
    self._snapshotCount=#self.ops
  end
  return self._snapshot
end

-- Apply a per-map override on top of the fused spec.
-- override: table with optional .tilesets and .heights keys.
-- Tileset overrides replace (not append) class groups for the given tileset.
function EditorModel:applyMapOverride(spec, override)
  if not override or type(override) ~= "table" then return spec end

  if override.tilesets then
    spec.tilesets = spec.tilesets or {}
    for tsetId, tsOverrides in pairs(override.tilesets) do
      if type(tsOverrides) == "table" then
        spec.tilesets[tsetId] = spec.tilesets[tsetId] or {}
        for class, tiles in pairs(tsOverrides) do
          if type(tiles) == "table" then
            spec.tilesets[tsetId][class] = tiles
          end
        end
      end
    end
  end

  if override.heights then
    for k, v in pairs(override.heights) do
      spec.heights[k] = v
    end
  end

  return spec
end

function EditorModel:applyOp(spec, op)
  if op.op == "define_class" then
    spec.classes = spec.classes or {}
    spec.classes[op.name] = self:deepcopy(op.definition)

  elseif op.op == "rename_class" or op.op == "edit_class" then
    spec.classes = spec.classes or {}
    local definition = spec.classes[op.old]
    spec.classes[op.old] = nil
    spec.classes[op.new] = self:deepcopy(op.definition or definition)
    if op.old ~= op.new then
      for _, ts in pairs(spec.tilesets or {}) do
        if type(ts) == "table" then
          if ts[op.old] ~= nil then
            ts[op.new] = ts[op.old]
            ts[op.old] = nil
          end
          for _, metadata in ipairs({"heights", "art", "doc"}) do
            if type(ts[metadata]) == "table" and ts[metadata][op.old] ~= nil then
              ts[metadata][op.new] = ts[metadata][op.old]
              ts[metadata][op.old] = nil
            end
          end
          if ts.terrain_edges and ts.terrain_edges.shoreClass == op.old then
            ts.terrain_edges.shoreClass = op.new
          end
          for _, field in ipairs({"when_above", "when_below"}) do
            if type(ts[field]) == "table" then
              for _, rules in pairs(ts[field]) do
                if type(rules) == "table" then
                  for _, rule in ipairs(rules) do
                    if type(rule) == "table" and rule.class == op.old then
                      rule.class = op.new
                    end
                  end
                end
              end
            end
          end
        end
      end
      if type(spec.heights) == "table" and spec.heights[op.old] ~= nil then
        spec.heights[op.new] = spec.heights[op.old]
        spec.heights[op.old] = nil
      end
    end

  elseif op.op == "delete_class" then
    spec.classes = spec.classes or {}
    spec.classes[op.name] = nil
    for _, ts in pairs(spec.tilesets or {}) do
      if type(ts) == "table" then
        if op.replacement and type(ts[op.name]) == "table" then
          ts[op.replacement] = ts[op.replacement] or {}
          for _, tile in ipairs(ts[op.name]) do
            local found = false
            for _, existing in ipairs(ts[op.replacement]) do
              if existing == tile then found = true; break end
            end
            if not found then ts[op.replacement][#ts[op.replacement] + 1] = tile end
          end
        end
        ts[op.name] = nil
        for _, metadata in ipairs({"heights", "art", "doc"}) do
          if type(ts[metadata]) == "table" then
            ts[metadata][op.name] = nil
          end
        end
        if op.replacement then
          if ts.terrain_edges and ts.terrain_edges.shoreClass == op.name then
            ts.terrain_edges.shoreClass = op.replacement
          end
          for _, field in ipairs({"when_above", "when_below"}) do
            if type(ts[field]) == "table" then
              for _, rules in pairs(ts[field]) do
                if type(rules) == "table" then
                  for _, rule in ipairs(rules) do
                    if type(rule) == "table" and rule.class == op.name then
                      rule.class = op.replacement
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
    if type(spec.heights) == "table" then
      spec.heights[op.name] = nil
    end

  elseif op.op == "pin" then
    spec.tilesets = spec.tilesets or {}
    spec.tilesets[op.tset] = spec.tilesets[op.tset] or {}
    local group = spec.tilesets[op.tset][op.class]
    if type(group) == "table" then
      for _, id in ipairs(group) do
        if id == op.tile then return end
      end
      group[#group + 1] = op.tile
    else
      spec.tilesets[op.tset][op.class] = {op.tile}
    end

  elseif op.op == "unpin" then
    local ts = spec.tilesets and spec.tilesets[op.tset]
    if not ts then return end
    local group = ts[op.class]
    if type(group) ~= "table" then return end
    for i = #group, 1, -1 do
      if group[i] == op.tile then
        table.remove(group, i)
        break
      end
    end
    if #group == 0 then ts[op.class] = nil end

  elseif op.op == "set_class" then
    local ts = spec.tilesets or {}
    ts[op.tset] = ts[op.tset] or {}
    local registered = {}
    for _, className in ipairs(self:classNames(spec)) do registered[className] = true end
    for className, tiles in pairs(ts[op.tset]) do
      if registered[className] and type(tiles) == "table" then
        local newTiles = {}
        for _, id in ipairs(tiles) do
          if id ~= op.tile then
            newTiles[#newTiles + 1] = id
          end
        end
        ts[op.tset][className] = #newTiles > 0 and newTiles or nil
      end
    end
    spec.tilesets[op.tset][op.class] = spec.tilesets[op.tset][op.class] or {}
    local group = spec.tilesets[op.tset][op.class]
    for _, id in ipairs(group) do
      if id == op.tile then return end
    end
    group[#group + 1] = op.tile

  elseif op.op == "height" then
    spec.tilesets = spec.tilesets or {}
    spec.tilesets[op.tset] = spec.tilesets[op.tset] or {}
    spec.tilesets[op.tset].heights = spec.tilesets[op.tset].heights or {}
    spec.tilesets[op.tset].heights[op.class] = op.h

  elseif op.op == "art" then
    spec.tilesets = spec.tilesets or {}
    spec.tilesets[op.tset] = spec.tilesets[op.tset] or {}
    spec.tilesets[op.tset].art = spec.tilesets[op.tset].art or {}
    spec.tilesets[op.tset].art[op.class] = op.mode

  elseif op.op == "mountain" or op.op == "border_blocks" or op.op == "terrain_edges" then
    spec.tilesets = spec.tilesets or {}
    spec.tilesets[op.tset] = spec.tilesets[op.tset] or {}
    spec.tilesets[op.tset][op.op] = self:deepcopy(op.value)

  elseif op.op == "spray" then
    spec.tilesets = spec.tilesets or {}
    spec.tilesets[op.tset] = spec.tilesets[op.tset] or {}
    spec.tilesets[op.tset].planter_spray = op.value

  elseif op.op == "prop_ground" then
    spec.tilesets = spec.tilesets or {}
    spec.tilesets[op.tset] = spec.tilesets[op.tset] or {}
    spec.tilesets[op.tset].prop_ground = spec.tilesets[op.tset].prop_ground or {}
    spec.tilesets[op.tset].prop_ground[op.tile] = op.ground

  elseif op.op == "when_below" then
    spec.tilesets = spec.tilesets or {}
    spec.tilesets[op.tset] = spec.tilesets[op.tset] or {}
    spec.tilesets[op.tset].when_below = spec.tilesets[op.tset].when_below or {}
    spec.tilesets[op.tset].when_below[op.tile] = op.rules

  elseif op.op == "when_above" then
    spec.tilesets = spec.tilesets or {}
    spec.tilesets[op.tset] = spec.tilesets[op.tset] or {}
    spec.tilesets[op.tset].when_above = spec.tilesets[op.tset].when_above or {}
    spec.tilesets[op.tset].when_above[op.tile] = op.rules

  elseif op.op == "doc" then
    spec.tilesets = spec.tilesets or {}
    spec.tilesets[op.tset] = spec.tilesets[op.tset] or {}
    spec.tilesets[op.tset].doc = spec.tilesets[op.tset].doc or {}
    spec.tilesets[op.tset].doc[op.class] = op.text

  elseif op.op == "add_tileset" then
    spec.tilesets = spec.tilesets or {}
    if not spec.tilesets[op.tset] then
      spec.tilesets[op.tset] = op.data or {}
    end

  elseif op.op == "building" then
    spec.buildings = spec.buildings or {}
    spec.buildings[op.tset] = spec.buildings[op.tset] or {}
    for i, b in ipairs(spec.buildings[op.tset]) do
      if b.id == op.id then
        spec.buildings[op.tset][i] = op.spec
        return
      end
    end
    spec.buildings[op.tset][#spec.buildings[op.tset] + 1] = op.spec

  elseif op.op == "building_delete" then
    local bl = spec.buildings and spec.buildings[op.tset]
    if not bl then return end
    for i = #bl, 1, -1 do
      if bl[i].id == op.id then
        table.remove(bl, i)
        break
      end
    end
  end
end

function EditorModel:push(op)
  self._snapshot=nil
  self.ops[#self.ops + 1] = op
  self.undoStack = {}
  return true
end

function EditorModel:undo()
  self._snapshot=nil
  if #self.ops == 0 then return false end
  local op = table.remove(self.ops)
  self.undoStack[#self.undoStack + 1] = op
  return true
end

function EditorModel:redo()
  self._snapshot=nil
  if #self.undoStack == 0 then return false end
  local op = table.remove(self.undoStack)
  self.ops[#self.ops + 1] = op
  return true
end

function EditorModel:defineClass(name, definition)
  local ok, spec = pcall(self.fuse, self)
  if not ok then return false, tostring(spec) end
  local valid, err = self:validateClasses(spec)
  if not valid then return false, err end
  if spec.classes and spec.classes[name] ~= nil then
    return false, "class already exists: " .. tostring(name)
  end
  local accepted, reason = ClassDefinitions.validate(name, definition,
    self:classMap(spec))
  if not accepted then return false, reason end
  local copied, clone = pcall(self.deepcopy, self, definition)
  if not copied then return false, tostring(clone) end
  self:push({op = "define_class", name = name, definition = clone})
  return true
end

function EditorModel:renameClass(oldName, newName)
  local ok, spec = pcall(self.fuse, self)
  if not ok then return false, tostring(spec) end
  local valid, err = self:validateClasses(spec)
  if not valid then return false, err end
  if not spec.classes or type(spec.classes[oldName]) ~= "table" then
    return false, "custom class not found: " .. tostring(oldName)
  end
  if spec.classes[newName] ~= nil or self:isClass(newName) then
    return false, "class already exists: " .. tostring(newName)
  end
  local accepted, reason = ClassDefinitions.validate(newName,
    spec.classes[oldName], self:classMap(spec))
  if not accepted then return false, reason end
  self:push({op = "rename_class", old = oldName, new = newName})
  return true
end

function EditorModel:editClass(oldName, newName, definition)
  local ok, spec = pcall(self.fuse, self)
  if not ok then return false, tostring(spec) end
  local valid, err = self:validateClasses(spec)
  if not valid then return false, err end
  if not spec.classes or type(spec.classes[oldName]) ~= "table" then
    return false, "custom class not found: " .. tostring(oldName)
  end
  newName = newName or oldName
  if newName ~= oldName and
     (spec.classes[newName] ~= nil or CLASS_SET[newName]) then
    return false, "class already exists: " .. tostring(newName)
  end
  local accepted, reason = ClassDefinitions.validate(newName, definition,
    self:classMap(spec))
  if not accepted then return false, reason end
  local copied, clone = pcall(self.deepcopy, self, definition)
  if not copied then return false, tostring(clone) end
  self:push({op = "edit_class", old = oldName, new = newName,
             definition = clone})
  return true
end

function EditorModel:deleteClass(name, replacement)
  local ok, spec = pcall(self.fuse, self)
  if not ok then return false, tostring(spec) end
  local valid, err = self:validateClasses(spec)
  if not valid then return false, err end
  if not spec.classes or type(spec.classes[name]) ~= "table" then
    return false, "custom class not found: " .. tostring(name)
  end
  if replacement ~= nil then
    if type(replacement) ~= "string" then
      return false, "replacement must be a class name"
    end
    if replacement == name or
       (not CLASS_SET[replacement] and not spec.classes[replacement]) then
      return false, "invalid replacement class: " .. replacement
    end
  end
  local used = false
  for _, ts in pairs(spec.tilesets or {}) do
    if type(ts) == "table" then
      if type(ts[name]) == "table" and #ts[name] > 0 then used = true end
      if ts.terrain_edges and ts.terrain_edges.shoreClass == name then used = true end
      for _, field in ipairs({"when_above", "when_below"}) do
        if type(ts[field]) == "table" then
          for _, rules in pairs(ts[field]) do
            if type(rules) == "table" then
              for _, rule in ipairs(rules) do
                if type(rule) == "table" and rule.class == name then used = true end
              end
            end
          end
        end
      end
    end
  end
  if used and not replacement then
    return false, "class is still referenced: " .. name
  end
  self:push({op = "delete_class", name = name, replacement = replacement})
  return true
end

function EditorModel:tileClass(tset, tile)
  local spec = self:fuse()
  local ts = spec.tilesets and spec.tilesets[tset]
  if not ts then return nil end
  local registered = {}
  for _, className in ipairs(self:classNames(spec)) do registered[className] = true end
  for _, className in ipairs(self:classNames(spec)) do
    local tiles = ts[className]
    if type(tiles) == "table" then
      for _, id in ipairs(tiles) do
        if id == tile then return className end
      end
    end
  end
  for className, tiles in pairs(ts) do
    if type(tiles) == "table" and not registered[className]
       and className ~= "doc" and className ~= "heights"
       and className ~= "art" and className ~= "prop_ground"
       and className ~= "terrain_edges" and className ~= "when_below" and className ~= "when_above"
       and className ~= "prop_bg" then
      for _, id in ipairs(tiles) do
        if id == tile then return className end
      end
    end
  end
  for _, cls in ipairs(CLASS_ORDER) do
    local tiles = ts[cls]
    if type(tiles) == "table" then
      for _, id in ipairs(tiles) do
        if id == tile then return cls end
      end
    end
  end
  return nil
end

function EditorModel:tileClassPinned(tset, tile)
  local ts = self.profile.tilesets and self.profile.tilesets[tset]
  if not ts then return nil end
  for _, cls in ipairs(self:classNames(self.profile)) do
    local tiles = ts[cls]
    if type(tiles) == "table" then
      for _, id in ipairs(tiles) do
        if id == tile then return cls end
      end
    end
  end
  return nil
end

function EditorModel:deepcopy(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do
    r[k] = self:deepcopy(v)
  end
  return r
end

function EditorModel:serialize(spec)
  spec = spec or (#self.ops==0 and self.profile or self:fuse())
  local out = {}

  out[#out + 1] = "-- Voxel world mode: the shape PROFILE for Pokemon Gold."
  out[#out + 1] = "--"
  out[#out + 1] = "-- Hand-authored pins over the automatic structure detector."
  out[#out + 1] = "-- Only tiles the detector must not touch need listing."
  out[#out + 1] = "--"
  out[#out + 1] = "-- EDITED BY VOXEL EDITOR -- do not hand-edit while the editor is active."
  out[#out + 1] = ""

  out[#out + 1] = "return " .. self:serializeValue(spec, 0)

  return table.concat(out, "\n") .. "\n"
end

function EditorModel:serializeValue(v, indent)
  indent = indent or 0
  local active = {}
  -- LuaJIT limits constants per function, not per file. Keep small profiles
  -- as ordinary literals, but construct large tables in bounded functions.
  local budget = 2048
  local sizes, measuring, packed = {}, {}, {}
  local editFields = {x=true,y=true,z=true,i=true,region=true,remove=true}
  local function compactable(value)
    if #value < 32 then return false end
    local count = 0
    for k,e in pairs(value) do
      if type(k)~='number' or k%1~=0 or k<1 or k>#value or type(e)~='table' then return false end
      count=count+1
      for field,n in pairs(e) do
        if not editFields[field] then return false end
        if field=='remove' then
          if type(n)~='boolean' then return false end
        elseif type(n)~='number' or n~=n or math.abs(n)>2147483647 or n%1~=0 then return false end
      end
    end
    return count==#value
  end
  local function measure(value, field)
    if type(value) ~= 'table' then return 1 end
    if measuring[value] then error('cannot serialize cyclic table', 3) end
    if sizes[value] then return sizes[value] end
    if field=='voxelEdits' and compactable(value) then
      packed[value]=true
      sizes[value]=budget+1
      return budget+1
    end
    measuring[value] = true
    local size = 1
    for k, child in pairs(value) do size = size + 2 + measure(k) + measure(child, k) end
    measuring[value] = nil
    sizes[value] = size
    return size
  end
  measure(v)
  local reserved = {
    ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true,
    ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true,
    ["function"] = true, ["goto"] = true, ["if"] = true, ["in"] = true,
    ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true,
    ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true,
    ["until"] = true, ["while"] = true,
  }
  local function spaces(n) return string.rep(" ", n) end
  local encode
  local function keyText(k)
    if type(k) == "string" and not reserved[k]
       and k:match("^[A-Za-z_][A-Za-z0-9_]*$") then
      return k .. " = "
    end
    return "[" .. encode(k) .. "] = "
  end
  encode = function(value, level)
    local kind = type(value)
    if value == nil then return "nil" end
    if kind == "string" then return string.format("%q", value) end
    if kind == "boolean" then return tostring(value) end
    if kind == "number" then
      if value ~= value or value == math.huge or value == -math.huge then
        error("cannot serialize non-finite number", 3)
      end
      return string.format("%.17g", value)
    end
    if kind ~= "table" then
      error("cannot serialize unsupported " .. kind, 3)
    end
    if active[value] then error("cannot serialize cyclic table", 3) end
    active[value] = true
    if packed[value] then
      -- Decode bounded strings instead of compiling a constructor for every
      -- sculpted voxel. The returned schema is unchanged and self-contained.
      local parts = {"(function() local v={} local function add(s) for x,y,z,i,r,d in s:gmatch('([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^;]*);') do local e={x=tonumber(x),y=tonumber(y),z=tonumber(z),i=tonumber(i),region=tonumber(r)} if d~='' then e.remove=d=='1' end v[#v+1]=e end end"}
      local rows={}
      for n,e in ipairs(value) do
        rows[#rows+1]=table.concat({e.x and tostring(e.x) or '',e.y and tostring(e.y) or '',
          e.z and tostring(e.z) or '',e.i and tostring(e.i) or '',e.region and tostring(e.region) or '',
          e.remove==nil and '' or (e.remove and '1' or '0')},',')..';'
        if #rows==512 or n==#value then
          parts[#parts+1]='add('..string.format('%q',table.concat(rows))..');'
          rows={}
        end
      end
      parts[#parts+1]='return v end)()'
      active[value]=nil
      return table.concat(parts,'\n')
    end
    local keys = self:sortedKeys(value)
    local isArray = #keys > 0
    if isArray then
      for i, k in ipairs(keys) do
        if type(k) ~= "number" or k ~= i then isArray = false; break end
      end
    end
    local result
    if #keys == 0 then
      result = "{}"
    elseif sizes[value] > budget then
      local parts = {'(function()', spaces(level + 2) .. 'local value = {};'}
      local weight = 0
      local opened = false
      for _, k in ipairs(keys) do
        local kt = type(k)
        if kt ~= 'string' and kt ~= 'number' and kt ~= 'boolean' then
          error('cannot serialize unsupported ' .. kt .. ' table key', 3)
        end
        local childSize = sizes[value[k]] or 1
        local cost = 3 + (childSize > budget and 1 or childSize)
        if not opened or weight + cost > budget then
          if opened then parts[#parts + 1] = spaces(level + 2) .. 'end)();' end
          parts[#parts + 1] = spaces(level + 2) .. '(function()'
          opened, weight = true, 0
        end
        parts[#parts + 1] = spaces(level + 4) .. 'value[' .. encode(k) .. '] = ' .. encode(value[k], level + 4) .. ';'
        weight = weight + cost
      end
      parts[#parts + 1] = spaces(level + 2) .. 'end)();'
      parts[#parts + 1] = spaces(level + 2) .. 'return value'
      parts[#parts + 1] = spaces(level) .. 'end)()'
      result = table.concat(parts, '\n')
    elseif isArray then
      local parts = {}
      for i = 1, #keys do parts[i] = encode(value[i], level + 2) end
      result = "{ " .. table.concat(parts, ", ") .. " }"
    else
      local parts = {}
      for _, k in ipairs(keys) do
        local kt = type(k)
        if kt ~= "string" and kt ~= "number" and kt ~= "boolean" then
          error("cannot serialize unsupported " .. kt .. " table key", 3)
        end
        parts[#parts + 1] = spaces(level + 2) .. keyText(k) .. encode(value[k], level + 2) .. ","
      end
      result = "{\n" .. table.concat(parts, "\n") .. "\n" .. spaces(level) .. "}"
    end
    active[value] = nil
    return result
  end
  return encode(v, indent)
end

function EditorModel:numsort(t)
  local r = {}
  for _, v in ipairs(t) do r[#r + 1] = v end
  table.sort(r, function(a, b)
    if type(a) == type(b) then return a < b end
    return type(a) < type(b)
  end)
  return r
end

function EditorModel:sortedKeys(t)
  local r = {}
  for k in pairs(t) do r[#r + 1] = k end
  table.sort(r, function(a, b)
    if type(a) == type(b) then
      if type(a) == "number" then return a < b end
      if type(a) == "boolean" then return not a and b end
      return tostring(a) < tostring(b)
    end
    return type(a) < type(b)
  end)
  return r
end

function EditorModel:save(path)
  local serialized, content = pcall(function()
    return self:serialize(#self.ops==0 and self.profile or self:fuse())
  end)
  if not serialized then return false, "cannot serialize: " .. tostring(content) end

  local temp
  local file
  for _ = 1, 100 do
    saveCounter = saveCounter + 1
    temp = path .. ".tmp." .. tostring(saveCounter)
    local opened, candidate = pcall(io.open, temp, "wx")
    if not opened then return false, "cannot open temporary file: " .. tostring(candidate) end
    if candidate then
      file = candidate
      break
    end
  end
  if not file then return false, "cannot create unique temporary file: " .. tostring(temp) end

  local function cleanup()
    pcall(os.remove, temp)
  end
  local function call(method, ...)
    local called, result, detail = pcall(method, file, ...)
    if not called then return false, result end
    if result == nil or result == false then return false, detail end
    return true
  end

  local written, writeErr = call(file.write, content)
  if not written then
    pcall(file.close, file)
    cleanup()
    return false, "cannot write temporary file: " .. tostring(writeErr)
  end
  local flushed, flushErr = call(file.flush)
  if not flushed then
    pcall(file.close, file)
    cleanup()
    return false, "cannot flush temporary file: " .. tostring(flushErr)
  end
  local closed, closeErr = call(file.close)
  if not closed then
    cleanup()
    return false, "cannot close temporary file: " .. tostring(closeErr)
  end

  local renamed, renameErr, renameDetail = pcall(os.rename, temp, path)
  if not renamed then
    cleanup()
    return false, "cannot rename temporary file: " .. tostring(renameErr)
  end
  if not renameErr then
    cleanup()
    return false, "cannot rename temporary file: " .. tostring(renameDetail or path)
  end
  return true
end

return EditorModel
