-- Data model for authored voxel geometry belonging to individual source tiles.
-- This is intentionally UI-free: FurnitureEditor and future 3-D controls can
-- use it without changing the established building `parts` schema.
local Shape = {}
Shape.__index = Shape

local KINDS = {box=true, slab=true, wedge=true, cylinder=true, plane=true}
local function copy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = copy(x) end
  return out
end
local function number(v, fallback)
  v = tonumber(v)
  return v and math.floor(v) or fallback
end
local function positive(v, fallback)
  return math.max(1, number(v, fallback))
end

local function normalizePart(part)
  part = type(part) == "table" and part or {}
  local p = copy(part)
  p.kind = KINDS[p.kind] and p.kind or "box"
  p.x, p.y, p.z = number(p.x, 0), number(p.y, 0), number(p.z, 0)
  p.w, p.h, p.d = positive(p.w, 1), positive(p.h, 1), positive(p.d, 1)
  if p.kind == "slab" then p.h = math.min(p.h, 1) end
  if p.kind == "plane" then p.d = 1 end
  if p.kind == "cylinder" then p.radius = positive(p.radius, math.min(p.w, p.d)) end
  return p
end

function Shape.new(template)
  local self = setmetatable({shapes = {}}, Shape)
  for tile, shape in pairs((template and template.tileShapes) or {}) do
    self:set(tile, shape)
  end
  return self
end

function Shape.normalize(shape)
  shape = type(shape) == "table" and shape or {}
  local out = {parts = {}}
  for k, v in pairs(shape) do
    if k ~= "parts" then out[k] = copy(v) end
  end
  for _, part in ipairs(shape.parts or {}) do out.parts[#out.parts + 1] = normalizePart(part) end
  return out
end

function Shape:tiles()
  local out = {}
  for tile in pairs(self.shapes) do out[#out + 1] = tile end
  table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
  return out
end

function Shape:get(tile)
  return self.shapes[tile]
end

function Shape:set(tile, shape)
  assert(tile ~= nil, "voxel shape requires a tile key")
  self.shapes[tile] = Shape.normalize(shape)
  return self.shapes[tile]
end

function Shape:remove(tile)
  if self.shapes[tile] == nil then return false end
  self.shapes[tile] = nil
  return true
end

function Shape:addPart(tile, part)
  local shape = self.shapes[tile] or self:set(tile, {})
  local normalized = normalizePart(part)
  shape.parts[#shape.parts + 1] = normalized
  return normalized
end

function Shape:updatePart(tile, index, patch)
  local shape = self.shapes[tile]
  if not shape or not shape.parts[index] then return nil, "unknown tile shape part" end
  local merged = copy(shape.parts[index])
  for k, v in pairs(patch or {}) do merged[k] = copy(v) end
  shape.parts[index] = normalizePart(merged)
  return shape.parts[index]
end

function Shape:removePart(tile, index)
  local shape = self.shapes[tile]
  if not shape or not shape.parts[index] then return false end
  table.remove(shape.parts, index)
  if #shape.parts == 0 and shape.keepEmpty ~= true then self.shapes[tile] = nil end
  return true
end

function Shape:duplicatePart(tile, index)
  local shape = self.shapes[tile]
  if not shape or not shape.parts[index] then return nil end
  local p = copy(shape.parts[index])
  shape.parts[#shape.parts + 1] = p
  return p
end

function Shape:export()
  local out = {}
  for tile, shape in pairs(self.shapes) do out[tile] = copy(shape) end
  return out
end

function Shape.validate(tileShapes)
  if tileShapes == nil then return true end
  if type(tileShapes) ~= "table" then return false, "tileShapes must be a table" end
  for tile, shape in pairs(tileShapes) do
    if type(tile) ~= "number" and type(tile) ~= "string" then return false, "tile key must be text or numeric" end
    if type(shape) ~= "table" or type(shape.parts) ~= "table" then return false, "shape parts missing" end
    for i, part in ipairs(shape.parts) do
      if type(part) ~= "table" or not KINDS[part.kind] then return false, "invalid voxel part at " .. tostring(tile) .. ":" .. i end
      for _, key in ipairs({"x", "y", "z", "w", "h", "d"}) do
        if type(part[key]) ~= "number" then return false, "voxel part coordinate missing: " .. key end
      end
    end
  end
  return true
end

return Shape
