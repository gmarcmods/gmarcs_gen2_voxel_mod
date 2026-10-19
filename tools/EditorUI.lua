local EditorUI = {}

local PANEL_BG = {0.16, 0.16, 0.19}
local BTN_BG = {0.24, 0.24, 0.27}
local BTN_HOVER = {0.34, 0.34, 0.38}
local BTN_ACTIVE = {0.40, 0.40, 0.46}
local BTN_TOGGLE = {0.28, 0.48, 0.72}
local TEXT = {0.88, 0.88, 0.88}
local TEXT_DIM = {0.52, 0.52, 0.56}
local BORDER = {0.34, 0.34, 0.38}
local GRID_LINE = {1, 1, 1, 0.12}

local CLASS_COLORS = {
  ground     = {0.42, 0.67, 0.30},
  water      = {0.22, 0.48, 0.82},
  void       = {0.45, 0.45, 0.45},
  ledge      = {0.70, 0.55, 0.30},
  fence      = {0.62, 0.48, 0.32},
  sign       = {0.78, 0.62, 0.28},
  wall       = {0.62, 0.36, 0.26},
  cliff      = {0.42, 0.32, 0.22},
  tree       = {0.18, 0.52, 0.24},
  roof       = {0.72, 0.28, 0.28},
  bed        = {0.78, 0.58, 0.78},
  stool      = {0.58, 0.44, 0.32},
  counter    = {0.56, 0.46, 0.36},
  backrest   = {0.66, 0.56, 0.42},
  table      = {0.52, 0.42, 0.32},
  desk       = {0.46, 0.36, 0.26},
  prop       = {0.72, 0.62, 0.42},
  cutout     = {0.76, 0.72, 0.58},
  bike       = {0.32, 0.52, 0.62},
  planter    = {0.12, 0.42, 0.18},
  sapling    = {0.32, 0.56, 0.28},
  relief     = {0.82, 0.78, 0.68},
  bookcase   = {0.42, 0.32, 0.22},
  stair_e    = {0.56, 0.56, 0.56},
  stair_n = {0.56, 0.56, 0.56},
  stair_down_n = {0.50, 0.50, 0.50},
  stair_w    = {0.56, 0.56, 0.56},
  stair_down_e = {0.50, 0.50, 0.50},
  stair_down_w = {0.50, 0.50, 0.50},
  billboard  = {0.62, 0.52, 0.72},
  console    = {0.56, 0.46, 0.66},
  signpost   = {0.78, 0.68, 0.32},
  post       = {0.62, 0.52, 0.36},
  can        = {0.68, 0.68, 0.68},
  stump      = {0.52, 0.42, 0.28},
  canopy     = {0.22, 0.56, 0.28},
  grass      = {0.38, 0.62, 0.28},
  building   = {0.82, 0.32, 0.32},
  flower     = {0.85, 0.45, 0.65},
}

function EditorUI.new()
  return setmetatable({
    mx = 0, my = 0,
    clicked = false, rightClicked = false,
    mouseDown = false,
    scrollDy = 0,
    hintText = nil,
    _scrollY = 0,
  }, {__index = EditorUI})
end

function EditorUI:beginFrame()
  self.hintText = nil
  self.mx, self.my = love.mouse.getPosition()
end

function EditorUI:endFrame()
  self.clicked = false
  self.rightClicked = false
  self.scrollDy = 0
end

function EditorUI:mousepressed(x, y, button)
  if button == 1 then self.clicked = true; self.mouseDown = true end
  if button == 2 then self.rightClicked = true end
end

function EditorUI:mousereleased(x, y, button)
  if button == 1 then self.mouseDown = false end
end

function EditorUI:mousemoved(x, y)
  self.mx, self.my = x, y
end

function EditorUI:wheelmoved(x, y)
  self.scrollDy = self.scrollDy + y
end

function EditorUI:classColor(class)
  return CLASS_COLORS[class] or {0.50, 0.50, 0.50}
end

function EditorUI:classColorAlpha(class, alpha)
  local c = CLASS_COLORS[class] or {0.50, 0.50, 0.50}
  return {c[1], c[2], c[3], alpha or 0.35}
end

function EditorUI:button(label, x, y, w, h, opts)
  opts = opts or {}
  local G = love.graphics
  local hov = self.mx >= x and self.mx <= x + w and self.my >= y and self.my <= y + h
  local wasClicked = hov and self.clicked

  local bg
  if opts.active then
    bg = BTN_TOGGLE
  elseif hov then
    bg = self.mouseDown and BTN_ACTIVE or BTN_HOVER
  else
    bg = opts.bg or BTN_BG
  end

  G.setColor(bg)
  G.rectangle("fill", x, y, w, h)
  if opts.outline then
    G.setColor(opts.outlineColor or BORDER)
    G.rectangle("line", x, y, w, h)
  end

  G.setColor(opts.fg or TEXT)
  local font = G.getFont()
  local lh = font and font:getHeight() or 14
  local lw = font and font:getWidth(label) or #label * 7
  local tx = x + (opts.centered and (w - lw) / 2 or 4)
  local ty = y + (h - lh) / 2
  G.print(label, tx, ty)
  G.setColor(1, 1, 1, 1)

  if hov and opts.hint then
    self.hintText = opts.hint
  end

  return wasClicked
end

function EditorUI:panel(x, y, w, h, opts)
  opts = opts or {}
  local G = love.graphics
  G.setColor(opts.bg or PANEL_BG)
  G.rectangle("fill", x, y, w, h)
  G.setColor(BORDER)
  G.rectangle("line", x, y, w, h)
  if opts.title then
    G.setColor(opts.titleFg or TEXT)
    G.print(opts.title, x + 6, y + 4)
  end
  G.setColor(1, 1, 1, 1)
end

function EditorUI:text(str, x, y, opts)
  opts = opts or {}
  local G = love.graphics
  G.setColor(opts.color or TEXT)
  G.print(str, x, y)
  G.setColor(1, 1, 1, 1)
end

function EditorUI:textDim(str, x, y)
  self:text(str, x, y, {color = TEXT_DIM})
end

function EditorUI:separator(x, y, w)
  local G = love.graphics
  G.setColor(BORDER)
  G.line(x, y, x + w, y)
  G.setColor(1, 1, 1, 1)
end

function EditorUI:palette(classes, selectedIdx, x, y, chipSize)
  chipSize = chipSize or 18
  local result = selectedIdx
  local G = love.graphics
  local rowH = chipSize + 2

  for i, cls in ipairs(classes) do
    local cy = y + (i - 1) * rowH
    local color = self:classColor(cls)
    local hov = self.mx >= x and self.mx <= x + chipSize and
                self.my >= cy and self.my <= cy + chipSize

    G.setColor(color)
    G.rectangle("fill", x, cy, chipSize, chipSize)
    if selectedIdx == i then
      G.setColor(1, 1, 1)
      G.rectangle("line", x, cy, chipSize, chipSize)
    end

    G.setColor(hov and {1, 1, 1} or TEXT)
    G.print(cls, x + chipSize + 4, cy + 1)

    if hov and self.clicked then
      result = i
    end
  end

  G.setColor(1, 1, 1, 1)
  return result
end

function EditorUI:stepper(label, value, x, y, w, opts)
  opts = opts or {}
  local result = nil
  local G = love.graphics
  local font = G.getFont()
  local lh = font and font:getHeight() or 14

  G.setColor(TEXT)
  G.print(label, x, y + 2)

  local vw = opts.valueWidth or 50
  local vx = x + w - vw - 38
  G.setColor({0.20, 0.20, 0.23})
  G.rectangle("fill", vx, y, vw, lh + 4)
  G.setColor(TEXT)
  G.print(tostring(value), vx + 4, y + 2)

  if self:button("-", vx + vw + 2, y, 16, lh + 4, {centered = true}) then
    result = value - (opts.step or 1)
  end
  if self:button("+", vx + vw + 20, y, 16, lh + 4, {centered = true}) then
    result = value + (opts.step or 1)
  end

  return result
end

function EditorUI:scrollArea(x, y, w, h, contentH, key)
  key = key or "_default"
  if not self._scrollStates then self._scrollStates = {} end
  if self._scrollStates[key] == nil then self._scrollStates[key] = 0 end

  local hov = self.mx >= x and self.mx <= x + w and
              self.my >= y and self.my <= y + h
  if hov then
    self._scrollStates[key] = self._scrollStates[key] - self.scrollDy * 24
    self._scrollStates[key] = math.max(0, math.min(self._scrollStates[key], math.max(0, contentH - h)))
  end

  local G = love.graphics
  G.setScissor(x, y, w, h)

  return self._scrollStates[key], y
end

function EditorUI:scrollEnd()
  love.graphics.setScissor()
end

function EditorUI:gridHit(mx, my, gx, gy, cellW, cellH)
  local tx = math.floor((mx - gx) / cellW)
  local ty = math.floor((my - gy) / cellH)
  if tx >= 0 and ty >= 0 then
    return tx, ty
  end
  return nil, nil
end

function EditorUI:gridTint(x, y, w, h, class, alpha)
  local G = love.graphics
  G.setColor(self:classColorAlpha(class, alpha or 0.30))
  G.rectangle("fill", x, y, w, h)
  G.setColor(1, 1, 1, 1)
end

function EditorUI:gridLines(x, y, cols, rows, cellW, cellH)
  local G = love.graphics
  G.setColor(GRID_LINE)
  for c = 0, cols do
    local lx = x + c * cellW
    G.line(lx, y, lx, y + rows * cellH)
  end
  for r = 0, rows do
    local ly = y + r * cellH
    G.line(x, ly, x + cols * cellW, ly)
  end
  G.setColor(1, 1, 1, 1)
end

function EditorUI:tooltip(text)
  if not text then return end
  local G = love.graphics
  local font = G.getFont()
  local tw = font:getWidth(text)
  local th = font:getHeight()
  local sw, sh = G.getDimensions()
  local tx = self.mx + 14
  local ty = self.my + 14
  if tx + tw + 8 > sw then tx = self.mx - tw - 14 end
  if ty + th + 8 > sh then ty = self.my - th - 14 end
  G.setColor(0.08, 0.08, 0.10, 0.94)
  G.rectangle("fill", tx - 4, ty - 2, tw + 8, th + 4)
  G.setColor(TEXT)
  G.print(text, tx, ty)
  G.setColor(1, 1, 1, 1)
end

function EditorUI:helpOverlay(lines)
  local G = love.graphics
  local sw, sh = G.getDimensions()
  G.setColor(0.06, 0.06, 0.08, 0.92)
  G.rectangle("fill", 0, 0, sw, sh)
  G.setColor(TEXT)
  local y = 50
  for _, line in ipairs(lines) do
    G.print(line, 50, y)
    y = y + 22
  end
  G.setColor(TEXT_DIM)
  G.print("Press ? or H to close", 50, y + 10)
  G.setColor(1, 1, 1, 1)
end

function EditorUI:list(items, selectedIdx, x, y, w, h, opts)
  opts = opts or {}
  local result = selectedIdx
  local G = love.graphics
  local font = G.getFont()
  local lh = font and font:getHeight() or 14
  local rowH = lh + 4
  local contentH = #items * rowH
  local scrollY = self:scrollArea(x, y, w, h, contentH)

  for i, item in ipairs(items) do
    local ry = y + (i - 1) * rowH - scrollY
    if ry + rowH > y and ry < y + h then
      local hov = self.mx >= x and self.mx <= x + w and
                  self.my >= ry and self.my <= ry + rowH
      local isSel = selectedIdx == i

      if isSel then
        G.setColor(0.25, 0.35, 0.50)
        G.rectangle("fill", x, ry, w, rowH)
      elseif hov then
        G.setColor(0.22, 0.22, 0.26)
        G.rectangle("fill", x, ry, w, rowH)
      end

      G.setColor(isSel and {1, 1, 1} or (hov and TEXT or TEXT_DIM))
      local label = type(item) == "string" and item or (item.label or tostring(item))
      G.print(label, x + 4, ry + 2)

      if hov and self.clicked then
        result = i
      end
    end
  end

  self:scrollEnd()
  G.setColor(1, 1, 1, 1)
  return result
end

function EditorUI:classList(allClasses, pinnedClasses, x, y, w, h, scrollKey)
  local G = love.graphics
  local font = G.getFont()
  local lh = font and font:getHeight() or 14
  local rowH = lh + 4
  local contentH = #allClasses * rowH
  local scrollY = self:scrollArea(x, y, w, h, contentH, scrollKey or "classes")

  for i, cls in ipairs(allClasses) do
    local ry = y + (i - 1) * rowH - scrollY
    if ry + rowH > y and ry < y + h then
      local color = self:classColor(cls)
      local pinned = pinnedClasses and pinnedClasses[cls]
      local hov = self.mx >= x and self.mx <= x + w and
                  self.my >= ry and self.my <= ry + rowH

      G.setColor(color)
      G.rectangle("fill", x, ry, 12, 12)

      if pinned then
        G.setColor(1, 1, 1)
        G.rectangle("line", x, ry, 12, 12)
      end

      G.setColor(hov and {1, 1, 1} or TEXT)
      G.print(cls, x + 16, ry + 1)

      if hov and self.clicked then
        return cls, i
      end
    end
  end

  self:scrollEnd()
  G.setColor(1, 1, 1, 1)
  return nil, nil
end

-- Modal overlay: darkens the screen, returns sw, sh for centering.
function EditorUI:modalOverlay()
  local lg = love.graphics
  local sw, sh = lg.getDimensions()
  lg.setColor(0.06, 0.06, 0.08, 0.88)
  lg.rectangle("fill", 0, 0, sw, sh)
  return sw, sh
end

-- Text input field (simple: renders current text, returns click state).
-- state = { text = "", focused = false }
-- Returns: state, committed (true when Enter pressed).
function EditorUI:textInput(prompt, x, y, w, state)
  local lg = love.graphics
  state = state or { text = "", focused = false }

  local fieldY, fieldH = y + 16, 20
  local inside = self.mx >= x and self.mx <= x + w and
                 self.my >= fieldY and self.my <= fieldY + fieldH

  local function setTextInput(enabled)
    if not (love.keyboard and love.keyboard.setTextInput) then return end
    pcall(love.keyboard.setTextInput, enabled)
  end

  -- A click belongs to this field only when it lands inside its rectangle.
  -- This lets another modal control receive an outside click without leaving
  -- the keyboard text-input mode active.
  if self.clicked then
    if inside then
      state.focused = true
    elseif state.focused then
      state.focused = false
    end
  end

  if state.focused and not state._textInputEnabled then
    setTextInput(true)
    state._textInputEnabled = true
  elseif not state.focused and state._textInputEnabled then
    setTextInput(false)
    state._textInputEnabled = nil
  end

  -- Apply events before drawing so text received by the parent is visible in
  -- this frame. _char may contain more than one character.
  local committed = false
  if state.focused then
    if type(state._char) == "string" then
      state.text = state.text .. state._char
      state._char = nil
    end
    if state._enter then
      committed = true
      state.focused = false
      state._enter = false
      if state._textInputEnabled then
        setTextInput(false)
        state._textInputEnabled = nil
      end
    end
    if state._back then
      state.text = state.text:sub(1, -2)
      state._back = false
    end
    if state._escape then
      state.focused = false
      state._escape = false
      if state._textInputEnabled then
        setTextInput(false)
        state._textInputEnabled = nil
      end
    end
  else
    state._char = nil
    state._enter = false
    state._back = false
    state._escape = false
  end

  lg.setColor(0.88, 0.88, 0.88)
  lg.print(prompt, x, y)
  -- Field background
  lg.setColor(0.20, 0.20, 0.23)
  lg.rectangle("fill", x, fieldY, w, fieldH)
  lg.setColor(state.focused and {0.30, 0.35, 0.50} or {0.25, 0.25, 0.28})
  lg.rectangle("line", x, fieldY, w, fieldH)
  -- Text
  lg.setColor(0.88, 0.88, 0.88)
  local display = state.text
  if #display > 30 then display = "..." .. display:sub(-27) end
  lg.print(display, x + 4, y + 19)
  -- Cursor blink
  if state.focused then
    local cursorX = x + 4 + lg.getFont():getWidth(display)
    if math.floor(love.timer.getTime() * 2) % 2 == 0 then
      lg.rectangle("fill", cursorX, fieldY + 2, 2, 14)
    end
  end
  return state, committed
end

-- Simple choice list: returns index of clicked item or nil.
function EditorUI:choiceList(items, x, y, w, itemH, scrollKey, maxHeight)
  local lg = love.graphics
  scrollKey = scrollKey or "choice"
  local totalH = #items * itemH
  local _, sh = lg.getDimensions()
  local availableH = maxHeight or (sh - y - 20)
  local maxH = math.max(0, math.min(totalH, availableH))
  local scrollY = self:scrollArea(x, y, w, maxH, totalH, scrollKey)
  for i, item in ipairs(items) do
    local ry = y + (i - 1) * itemH - scrollY
    if ry + itemH > y and ry < y + maxH then
      local hov = self.mx >= x and self.mx <= x + w and
                  self.my >= ry and self.my <= ry + itemH
      if hov then
        lg.setColor(0.35, 0.40, 0.55)
        lg.rectangle("fill", x, ry, w, itemH)
      end
      lg.setColor(hov and {1, 1, 1} or TEXT)
      lg.print(item.label or item, x + 4, ry + 2)
      if hov and self.clicked then
        self:scrollEnd()
        return i, item
      end
    end
  end
  self:scrollEnd()
  return nil, nil
end

return EditorUI
