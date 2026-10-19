-- Validation and presentation helpers for editor-defined voxel classes.
local ClassDefinitions = {}

ClassDefinitions.RESERVED_NAMES = {
  -- Lua syntax words cannot be emitted as bare class keys by the editor.
  ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true,
  ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true,
  ["function"] = true, ["goto"] = true, ["if"] = true, ["in"] = true,
  ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true,
  ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true,
  ["until"] = true, ["while"] = true,
  -- Per-tileset metadata consumed by TileShape and Structures.
  border_blocks = true, mountain = true, terrain_edges = true, heights = true, art = true, doc = true, figures = true, mounted = true,
  when_above = true, when_below = true, prop_ground = true, prop_bg = true,
  planter_spray = true, bookcase_relief = true, bookcase_backfill = true,
  can_height = true, sapling_squash = true, cylinder_depth = true,
}

ClassDefinitions.ART_MODES = {
  flat = true, top = true, upright = true, billboard = true,
  relief = true, bookcase = true, stair = true, cylinder = true,
}

local function finite(n)
  return type(n) == "number" and n == n and n ~= math.huge
     and n ~= -math.huge
end

function ClassDefinitions.validate(name, definition, builtins)
  if type(name) ~= "string" or not name:match("^[%a_][%w_]*$") then
    return false, "class name must be a Lua identifier"
  end
  if ClassDefinitions.RESERVED_NAMES[name] then
    return false, "class name is reserved: " .. name
  end
  builtins = builtins or {}
  if builtins[name] ~= nil then return false, "class shadows builtin: " .. name end
  if type(definition) ~= "table" then return false, "definition must be a table" end
  if type(definition.base) ~= "string" or builtins[definition.base] == nil then
    return false, "base must name a builtin class"
  end
  local minimum = definition.base == "void" and -128 or -2
  if not finite(definition.height) or definition.height % 1 ~= 0
     or definition.height < minimum or definition.height > 128 then
    return false, "height must be a finite integer from " .. minimum .. " to 128"
  end
  if definition.art ~= nil and not ClassDefinitions.ART_MODES[definition.art] then
    return false, "unsupported art mode: " .. tostring(definition.art)
  end
  if definition.label ~= nil and type(definition.label) ~= "string" then
    return false, "label must be a string"
  end
  return true
end

function ClassDefinitions.validateAll(classes, builtins)
  if type(classes) ~= "table" then return false, "classes must be a table" end
  builtins = builtins or {}
  for name, definition in pairs(classes) do
    local ok, err = ClassDefinitions.validate(name, definition, builtins)
    if not ok then return false, err end
  end
  return true
end

function ClassDefinitions.names(spec, builtinOrder)
  local out, seen = {}, {}
  for _, name in ipairs(builtinOrder or {}) do
    if not seen[name] then out[#out + 1] = name; seen[name] = true end
  end
  local custom = {}
  for name in pairs(spec or {}) do
    if not seen[name] then custom[#custom + 1] = name end
  end
  table.sort(custom)
  for _, name in ipairs(custom) do out[#out + 1] = name end
  return out
end

return ClassDefinitions
