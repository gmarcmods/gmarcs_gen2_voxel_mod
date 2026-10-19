-- Standalone authoring dialog for building templates made from furniture parts.
-- The part tables deliberately use the schema consumed by lib/Buildings.lua.
local Dialog = {}
Dialog.__index = Dialog
local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("(.+)/tools/FurnitureEditor.lua$") or "."
local VoxelShape = dofile(root .. "/tools/VoxelShapeModel.lua")

local KINDS = {"flat", "box", "upright"}
local PRESETS = {
  chair = {
    {kind="flat", x={4, 27}, rows={8, 10}, z=0, at=4, thick=2},
    {kind="upright", x={5, 26}, top={0, 3}, facade={4, 7}, z=8, depth=2, rise=0},
    {kind="box", x={5, 9}, rows={11, 15}, z=0, depth=2, base=0},
    {kind="box", x={22, 26}, rows={11, 15}, z=0, depth=2, base=0},
  },
  table = {
    {kind="flat", x={0, 31}, rows={0, 3}, z=0, at=8, thick=2},
    {kind="box", x={3, 7}, rows={4, 15}, z=0, depth=2, base=0},
    {kind="box", x={24, 28}, rows={4, 15}, z=0, depth=2, base=0},
  },
  shelf = {
    {kind="upright", x={0, 3}, top={0, 3}, facade={4, 31}, z=0, depth=2, rise=0},
    {kind="upright", x={28, 31}, top={0, 3}, facade={4, 31}, z=0, depth=2, rise=0},
    {kind="flat", x={4, 27}, rows={8, 10}, z=0, at=4, thick=2},
    {kind="flat", x={4, 27}, rows={16, 18}, z=0, at=8, thick=2},
    {kind="flat", x={4, 27}, rows={24, 26}, z=0, at=12, thick=2},
  },
}

local function copy(model, value)
  if model and model.deepcopy then return model:deepcopy(value) end
  if type(value) ~= "table" then return value end
  local out = {}
  for k, v in pairs(value) do out[k] = copy(model, v) end
  return out
end

local function int(value, fallback)
  value = tonumber(value)
  if not value then return fallback end
  return math.floor(value)
end

local function range(v, lo, hi, fallback)
  v = type(v) == "table" and {int(v[1], fallback), int(v[2], fallback)}
      or {fallback, fallback}
  v[1], v[2] = math.max(lo, math.min(hi, v[1])), math.max(lo, math.min(hi, v[2]))
  if v[1] > v[2] then v[1], v[2] = v[2], v[1] end
  return v
end

function Dialog.new(model, tset, tiles, existingTemplate)
  assert(type(tiles) == "table", "FurnitureEditor requires a tiles grid")
  assert(#tiles > 0 and type(tiles[1]) == "table" and #tiles[1] > 0,
    "FurnitureEditor requires a non-empty tiles grid")
  local template = copy(model, existingTemplate or {})
  local rows = #tiles * 8
  local cols = (#tiles > 0 and #(tiles[1] or {}) or 0) * 8
  template.tiles = copy(model, tiles)
  -- These are the smallest valid building envelope fields consumed by
  -- Buildings.measure. Keep authored values when editing an existing one.
  template.roofRows = template.roofRows or 0
  template.roofBack = template.roofBack or 0
  template.roofFront = template.roofFront or 0
  template.roofCycle = template.roofCycle or {0, 0}
  template.slab = template.slab or 0
  template.frontEave = template.frontEave or 0
  template.depthPx = template.depthPx or math.max(8, #tiles * 8)
  local parts = copy(model, template.parts or {})
  local self = setmetatable({model=model, tset=tset, tiles=tiles, cols=cols, rows=rows,
    template=template, name={text=template.id or "", focused=true}, parts=parts,
    shapeModel=VoxelShape.new(template), originalId=template.id, depthPx=template.depthPx,
    selected=1, error=nil}, Dialog)
  return self
end

function Dialog:normalizePart(p)
  p.kind = p.kind == "flat" and "flat" or p.kind == "box" and "box" or "upright"
  p.x = range(p.x, 0, math.max(0, self.cols - 1), 0)
  if p.kind == "upright" then
    p.top = range(p.top, 0, math.max(0, self.rows - 1), 0)
    p.facade = range(p.facade, 0, math.max(0, self.rows - 1), p.top[1])
    p.depth, p.rise, p.z = math.max(1, int(p.depth, 1)), math.max(0, int(p.rise, 0)), math.max(0, int(p.z, 0))
  else
    p.rows = range(p.rows, 0, math.max(0, self.rows - 1), 0)
    p.z = math.max(0, int(p.z, 0))
    if p.kind == "flat" then
      p.at, p.thick = math.max(0, int(p.at, 0)), math.max(1, int(p.thick, 1))
    else
      p.depth, p.base = math.max(1, int(p.depth, 1)), math.max(0, int(p.base, 0))
    end
  end
end

function Dialog:normalize()
  for _, p in ipairs(self.parts) do self:normalizePart(p) end
end

-- The tile shape editor uses source tile IDs as stable keys. Keeping this
-- separate from `parts` lets old templates continue to load unchanged.
function Dialog:tileShape(tile)
  return self.shapeModel:get(tile)
end

function Dialog:setTileShape(tile, shape)
  return self.shapeModel:set(tile, shape)
end

function Dialog:addPart(kind)
  local p = {kind=kind or "upright", x={0, math.min(1, self.cols - 1)}, rows={0, math.min(1, self.rows - 1)},
    top={0, math.min(1, self.rows - 1)}, facade={0, math.min(1, self.rows - 1)}, z=0, depth=1, rise=0,
    at=0, thick=1, base=0}
  self:normalizePart(p)
  self.parts[#self.parts + 1] = p
  self.selected = #self.parts
  return p
end

function Dialog:duplicatePart(index)
  local p = self.parts[index or self.selected]
  if not p then return nil end
  local n = copy(self.model, p)
  self.parts[#self.parts + 1] = n
  self.selected = #self.parts
  return n
end

function Dialog:removePart(index)
  index = index or self.selected
  if not self.parts[index] then return false end
  table.remove(self.parts, index)
  self.selected = math.max(1, math.min(index, #self.parts))
  return true
end

function Dialog:addPreset(name)
  local preset = PRESETS[name]
  if not preset then return false end
  for _, p in ipairs(preset) do self.parts[#self.parts + 1] = copy(self.model, p); self:normalizePart(self.parts[#self.parts]) end
  self.selected = #self.parts
  return true
end

function Dialog:apply(applied, close)
  local id = tostring(self.name.text or ""):gsub("[^%w_]", "")
  if id == "" then self.error = "Template name is required"; return false end
  if #self.parts == 0 then self.error = "At least one furniture part is required"; return false end
  local fused = self.model:fuse()
  for _, building in ipairs((fused.buildings or {})[self.tset] or {}) do
    if building.id == id and building.id ~= self.originalId then
      self.error = "Template name already exists: " .. id
      return false
    end
  end
  local spec = copy(self.model, self.template)
  local tileShapes = self.shapeModel:export()
  local valid, reason = VoxelShape.validate(tileShapes)
  if not valid then self.error = reason; return false end
  spec.id, spec.tiles, spec.parts, spec.depthPx = id, copy(self.model, self.tiles), copy(self.model, self.parts), self.depthPx
  if next(tileShapes) then spec.tileShapes = tileShapes else spec.tileShapes = nil end
  -- `id` on the operation selects the existing entry. The spec carries the
  -- new name, allowing a rename to remain one undoable replacement.
  self.model:push({op="building", tset=self.tset, id=self.originalId or id, spec=spec})
  if applied then applied(id) end
  if close then close() end
  return true
end

function Dialog:delete(applied, close)
  if not self.originalId then self.error = "Only saved templates can be deleted"; return false end
  self.model:push({op="building_delete", tset=self.tset, id=self.originalId})
  if applied then applied(self.originalId) end
  if close then close() end
  return true
end

function Dialog:cancel(close)
  if close then close() end
end

local function step(ui, label, value, x, y, w)
  local result = ui:stepper(label, value, x, y, w)
  return result == nil and value or int(result, value)
end

function Dialog:draw(ui, model, applied, close)
  local sw, sh = ui:modalOverlay()
  local w, h = math.min(1000, sw - 24), math.min(700, sh - 24)
  local x, y = (sw - w) / 2, (sh - h) / 2
  love.graphics.setColor(0.12, 0.14, 0.18); love.graphics.rectangle("fill", x, y, w, h)
  love.graphics.setColor(0.9, 0.9, 0.9); love.graphics.print("Voxel Asset Workspace", x + 12, y + 10)
  -- Live isometric voxel viewport. It deliberately renders the authored
  -- boxes directly, so changing a dimension immediately changes something
  -- visible instead of forcing the author to reason from numbers.
  local vx, vy, vw, vh = x + 16, y + 42, math.min(500, w * 0.52), h - 110
  love.graphics.setColor(0.04, 0.05, 0.08); love.graphics.rectangle("fill", vx, vy, vw, vh)
  love.graphics.setColor(0.25, 0.28, 0.34); love.graphics.rectangle("line", vx, vy, vw, vh)
  self.viewScale = self.viewScale or 7
  self.viewYaw = self.viewYaw or 0
  self.viewPitch = self.viewPitch or 0.55
  local scale = self.viewScale
  local function project(px, py, pz)
    local cyaw, syaw = math.cos(self.viewYaw), math.sin(self.viewYaw)
    local ax, az = px * cyaw - pz * syaw, px * syaw + pz * cyaw
    return vx + vw * 0.5 + ax * scale, vy + vh * 0.72 + az * scale * 0.45 - py * scale
  end
  local function cube(px, py, pz, color, selected)
    local cx, cy = project(px, py, pz)
    local hw, hh = scale * 0.5, scale * 0.25
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.polygon("fill", cx, cy-hh, cx+hw, cy, cx, cy+hh, cx-hw, cy)
    love.graphics.setColor(color[1]*0.7, color[2]*0.7, color[3]*0.7, 1)
    love.graphics.polygon("fill", cx-hw, cy, cx, cy+hh, cx, cy+hh+scale, cx-hw, cy+scale)
    love.graphics.setColor(color[1]*0.82, color[2]*0.82, color[3]*0.82, 1)
    love.graphics.polygon("fill", cx+hw, cy, cx, cy+hh, cx, cy+hh+scale, cx+hw, cy+scale)
    if selected then
      love.graphics.setColor(1, 0.85, 0.2, 1); love.graphics.polygon("line", cx, cy-hh, cx+hw, cy, cx, cy+hh, cx-hw, cy)
    end
  end
  local function hitPart(mx, my)
    local best, bestDist
    local shapesNow = self.shapeModel:export()
    for tile, shape in pairs(shapesNow) do
      for index, part in ipairs(shape.parts or {}) do
        local px = (part.x or 0) + (part.w or 1) * 0.5
        local py = (part.y or 0) + (part.h or 1) * 0.5
        local pz = (part.z or 0) + (part.d or 1) * 0.5
        local sx, sy = project(px, py, pz)
        local d = (sx-mx)^2 + (sy-my)^2
        if d < (bestDist or 18*18) then bestDist, best = d, {tile=tile,index=index} end
      end
    end
    return best
  end
  local shapes = self.shapeModel:export()
  if next(shapes) == nil and #self.parts > 0 then
    local tile = self.tiles[1] and self.tiles[1][1] or 0
    shapes[tile] = {parts={}}
    for _, legacy in ipairs(self.parts) do
      local x0 = legacy.x and legacy.x[1] or 0
      local x1 = legacy.x and legacy.x[2] or x0
      local z0 = legacy.z or 0
      local rows = legacy.rows or {z0,z0}
      shapes[tile].parts[#shapes[tile].parts+1] = {
        x=x0, y=legacy.at or 0, z=z0, w=math.max(1,x1-x0+1),
        h=math.max(1,legacy.thick or legacy.depth or 1), d=math.max(1,rows[2]-rows[1]+1)}
    end
  end
  for tile, shape in pairs(shapes) do
    local tileIndex = 0
    for r,row in ipairs(self.tiles) do for c,id in ipairs(row) do if id == tile then tileIndex=(r-1)*#row+(c-1); end end end
    local tx, tz = (tileIndex % math.max(1,#self.tiles[1])) * 8, math.floor(tileIndex / math.max(1,#self.tiles[1])) * 8
    for _, part in ipairs(shape.parts or {}) do
      local col = tile == self.shapeTile and {0.3,0.75,1.0} or {0.65,0.68,0.75}
      for px=part.x or 0,(part.x or 0)+(part.w or 1)-1 do for py=part.y or 0,(part.y or 0)+(part.h or 1)-1 do
        for pz=part.z or 0,(part.z or 0)+(part.d or 1)-1 do cube(tx+px,py,tz+pz,col,tile==self.shapeTile) end
      end end
    end
  end
  love.graphics.setColor(0.75,0.78,0.85); love.graphics.print("VOXEL VIEWPORT  •  blue = selected tile", vx+8, vy+8)
  if ui.scrollDy and ui.mx >= vx and ui.mx <= vx+vw and ui.my >= vy and ui.my <= vy+vh then
    self.viewScale = math.max(3, math.min(18, self.viewScale + ui.scrollDy * 0.6))
  end
  if ui.mouseDown and self._viewDrag and self._viewDrag.x then
    self.viewYaw = self.viewYaw + (ui.mx - self._viewDrag.x) * 0.012
    self.viewPitch = math.max(0.2, math.min(1.1, self.viewPitch + (ui.my - self._viewDrag.y) * 0.006))
    self._viewDrag.x, self._viewDrag.y = ui.mx, ui.my
  elseif ui.clicked and ui.mx >= vx and ui.mx <= vx+vw and ui.my >= vy and ui.my <= vy+vh then
    self._viewDrag = {x=ui.mx,y=ui.my}
  elseif not ui.mouseDown then
    self._viewDrag = nil
  end
  -- Direct authoring: a click in the viewport places a small voxel block at
  -- the nearest ground coordinate. The inspector then edits that selection.
  if ui.clicked and ui.mx >= vx and ui.mx <= vx + vw and ui.my >= vy and ui.my <= vy + vh and not ui.rightClicked then
    local hit = hitPart(ui.mx, ui.my)
    if hit then
      self.shapeTile, self.shapePart = hit.tile, hit.index
    end
    local scale = self.viewScale
    local dx, dy = ui.mx - (vx + vw * 0.5), ui.my - (vy + 150)
    local gx = math.max(0, math.floor((dx / scale + dy / (scale * 0.5)) * 0.5))
    local gz = math.max(0, math.floor((dy / (scale * 0.5) - dx / scale) * 0.5))
    if not hit then
      self.shapeModel:addPart(self.shapeTile, {kind="box", x=gx, y=0, z=gz, w=2, h=2, d=2})
      local current = self.shapeModel:get(self.shapeTile)
      self.shapePart = #current.parts
    end
  end
  if ui.rightClicked and ui.mx >= vx and ui.mx <= vx + vw and ui.my >= vy and ui.my <= vy + vh then
    local hit = hitPart(ui.mx, ui.my)
    if hit then self.shapeModel:removePart(hit.tile, hit.index) end
  end
  -- The inspector occupies the right side of the workspace; keeping its
  -- origin separate prevents controls from being drawn over the viewport.
  x = x + vw + 28
  w = w - vw - 40
  local committed
  self.name, committed = ui:textInput("Name", x + 12, y + 30, w - 24, self.name)
  ui._textInputState = self.name
  self.depthPx = step(ui, "Asset depth", self.depthPx, x + 12, y + 62, 170)
  local listY = y + 78
  local choices = {}
  for i, p in ipairs(self.parts) do choices[i] = {label = i .. ": support geometry"} end
  local picked = ui:choiceList(choices, x + 12, listY, 120, 22, "furniture_parts", 150)
  if picked then self.selected = picked end
  local by = y + h - 34
  local presetY = by - 28
  if ui:button("Add", x + 12, by, 56, 22) then self:addPart() end
  if ui:button("Duplicate", x + 72, by, 82, 22) then self:duplicatePart() end
  if ui:button("Remove", x + 158, by, 70, 22) then self:removePart() end
  local presetX = x + 12
  for _, preset in ipairs({"chair", "table", "shelf"}) do
    if ui:button(preset, presetX, presetY, 58, 22) then self:addPreset(preset) end
    presetX = presetX + 62
  end
  local p = self.parts[self.selected]
  if p then
    local px, py = x + 150, listY
    for _, kind in ipairs(KINDS) do
      if ui:button(kind, px, py, 76, 20, {active=p.kind == kind}) then p.kind = kind; self:normalizePart(p) end
      px = px + 80
    end
    local function rangeFields(label, key, yy)
      p[key][1] = step(ui, label .. " min", p[key][1], x + 150, yy, 220)
      p[key][2] = step(ui, label .. " max", p[key][2], x + 380, yy, 220)
    end
    rangeFields(p.kind == "upright" and "top" or "rows", p.kind == "upright" and "top" or "rows", py + 32)
    rangeFields("x", "x", py + 62)
    if p.kind == "upright" then rangeFields("facade", "facade", py + 92) end
    if p.kind == "flat" then
      p.z = step(ui, "z", p.z, x + 150, py + 122, 220)
      p.at = step(ui, "at", p.at, x + 150, py + 152, 220)
      p.thick = step(ui, "thick", p.thick, x + 380, py + 152, 220)
    elseif p.kind == "upright" then
      p.z = step(ui, "z", p.z, x + 150, py + 122, 220)
      p.depth = step(ui, "depth", p.depth, x + 380, py + 122, 220)
      p.rise = step(ui, "rise", p.rise, x + 150, py + 152, 220)
    else
      p.z = step(ui, "z", p.z, x + 150, py + 122, 220)
      p.depth = step(ui, "depth", p.depth, x + 380, py + 122, 220)
      p.base = step(ui, "base", p.base, x + 150, py + 152, 220)
    end
  end
  -- Per-source-tile voxel geometry.  Tile IDs are stable keys, so a
  -- multi-tile object such as a TV can give each tile its own 3-D shape.
  local tileIds, seen = {}, {}
  for _, row in ipairs(self.tiles) do for _, tile in ipairs(row) do
    if not seen[tile] then seen[tile] = true; tileIds[#tileIds + 1] = tile end
  end end
  table.sort(tileIds, function(a,b) return tostring(a) < tostring(b) end)
  self.shapeTile = self.shapeTile or tileIds[1]
  local sy = y + 300
  local tileChoices = {}
  for i, tile in ipairs(tileIds) do tileChoices[i] = {label="Tile " .. tostring(tile)} end
  local ti = 1; for i,tile in ipairs(tileIds) do if tile == self.shapeTile then ti=i end end
  local pickedTile = ui:choiceList(tileChoices, x + 12, sy, 120, 20, "shape_tiles", 80)
  if pickedTile then self.shapeTile = tileIds[pickedTile] end
  local shape = self.shapeModel:get(self.shapeTile) or {parts={}}
  local shapeParts = shape.parts or {}
  local si = math.min(self.shapePart or 1, math.max(1, #shapeParts))
  self.shapePart = si
  local choices = {}; for i,part in ipairs(shapeParts) do choices[i] = {label=i .. ": " .. part.kind} end
  local picked = ui:choiceList(choices, x + 150, sy, 120, 20, "shape_parts", 80)
  if picked then self.shapePart = picked; si = picked end
  if ui:button("Add shape", x + 280, sy, 86, 20) then
    self.shapeModel:addPart(self.shapeTile, {kind="box", x=0,y=0,z=0,w=2,h=2,d=2})
    self.shapePart = #shapeParts + 1
  end
  if ui:button("Duplicate", x + 372, sy, 82, 20) then self.shapeModel:duplicatePart(self.shapeTile, si) end
  if ui:button("Remove", x + 460, sy, 70, 20) then self.shapeModel:removePart(self.shapeTile, si) end
  local sp = self.shapeModel:get(self.shapeTile) and self.shapeModel:get(self.shapeTile).parts[self.shapePart]
  if sp then
    local kinds = {"box", "slab", "wedge", "cylinder", "plane"}
    local kchoices = {}; for i,kind in ipairs(kinds) do kchoices[i]={label=kind} end
    local ki=1; for i,kind in ipairs(kinds) do if sp.kind==kind then ki=i end end
    local nk=ui:choiceList(kchoices,x+150,sy+28,90,18,"shape_kind",80)
    if nk then sp.kind=kinds[nk]; self.shapeModel:updatePart(self.shapeTile,self.shapePart,sp) end
    sp.x=step(ui,"x",sp.x,x+150,sy+52,105); sp.y=step(ui,"y",sp.y,x+265,sy+52,105); sp.z=step(ui,"z",sp.z,x+380,sy+52,105)
    sp.w=step(ui,"width",sp.w,x+150,sy+82,105); sp.h=step(ui,"height",sp.h,x+265,sy+82,105); sp.d=step(ui,"depth",sp.d,x+380,sy+82,105)
    self.shapeModel:updatePart(self.shapeTile,self.shapePart,sp)
  end
  if ui:button("Apply", x + w - 180, by, 78, 22) or committed then self:apply(applied, close) end
  if self.originalId and ui:button("Delete", x + w - 266, by, 78, 22) then
    self.deleting = true
  end
  if self.deleting and ui:button("Confirm delete", x + w - 266, by - 28, 110, 22) then
    self:delete(applied, close)
  end
  if ui:button("Cancel", x + w - 94, by, 78, 22) then self:cancel(close) end
  if self.error then love.graphics.print(self.error, x + 12, by - 24) end
end

return Dialog
