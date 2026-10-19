-- Overworld battles: the HUD's footing on a world that is not white.
--
-- Gen 1 draws its battle HUDs as black glyphs and bar tiles straight onto
-- the white field, with no box around them -- the field IS the backing. Take
-- the field away and put a route underneath and the name, the level and the
-- HP numbers are black on grass, which is not readable.
--
-- So each HUD block gets a panel: the world behind it, blurred to frosted
-- glass and laid back down translucent, with a tint that pushes it away from
-- whatever colour the text is about to be. Frosted rather than opaque
-- because the point of the mode is that you can see where you are standing,
-- and an opaque slab in the corner of the frame is the white field back
-- again by another name.
--
-- The ink does NOT change. There was a pass here that measured each panel's
-- average brightness and flipped the glyphs to white over a dark one, with
-- hysteresis so a drifting camera could not strobe them. It worked, and it
-- was still wrong: the battle menu is the one part of the frame the player
-- reads constantly, and having its colour depend on what the camera happens
-- to be pointing at makes it an unreliable piece of furniture. Gen 1's
-- battle text is black, so it is black -- and the panel's tint is what
-- earns that its contrast, on a cave floor as much as on a meadow.
--
-- Removing it also took out a one-pixel GPU readback that ran several times
-- a second purely to answer a question nothing asks any more.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local BattleGlass = {}

-- How solid the frost is over the world behind it, and how far the tint
-- pushes it toward the far end from the text.
--
-- Both deliberately light. The panel is there to make glyphs legible, not to
-- put a slab in the corner of the frame: at these values the sharp world
-- still reads through it and the blur registers as a pane of glass rather
-- than as a second background.
BattleGlass.FROST = 0.55
BattleGlass.TINT = 0.26

-- The frost buffer's height; width follows the source's aspect. Small on
-- purpose: the downscale is most of the blur.
BattleGlass.FROST_H = 72

local frost, frostW, frostH = nil, 0, 0
local blurA, blurB = nil, nil

local SHADER = [[
  uniform vec2 dir;
  vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec4 sum = Texel(tex, tc) * 0.2270270270;
    sum += (Texel(tex, tc + dir) + Texel(tex, tc - dir)) * 0.1945945946;
    sum += (Texel(tex, tc + 2.0 * dir) + Texel(tex, tc - 2.0 * dir)) * 0.1216216216;
    sum += (Texel(tex, tc + 3.0 * dir) + Texel(tex, tc - 3.0 * dir)) * 0.0540540541;
    sum += (Texel(tex, tc + 4.0 * dir) + Texel(tex, tc - 4.0 * dir)) * 0.0162162162;
    return sum * color;
  }
]]

local shader = nil            -- nil = untried, false = unavailable

local function getShader()
  if shader == nil then
    local ok, sh = pcall(love.graphics.newShader, SHADER)
    shader = (ok and sh) or false
  end
  return shader or nil
end

local function canvasOf(w, h, filter)
  local ok, c = pcall(love.graphics.newCanvas, w, h, { dpiscale = 1 })
  if not ok then return nil end
  c:setFilter(filter or "linear", filter or "linear")
  return c
end

-- Build (or rebuild) the frosted copy of `src` for this frame.
--
-- Two steps, because one is not enough: the downscale to a 72-row buffer
-- averages the world down to something that no longer reads as terrain, and
-- the separable gaussian over that turns the remaining structure into
-- frosted glass rather than a mosaic of the tiles it came from.
function BattleGlass.build(src)
  if not src then return nil end
  local blur = getShader()
  local sw, sh = src:getDimensions()
  if sw <= 0 or sh <= 0 then return nil end
  local h = BattleGlass.FROST_H
  local w = math.max(1, math.floor(sw * h / sh + 0.5))
  if not frost or frostW ~= w or frostH ~= h then
    frost = canvasOf(w, h)
    blurA = canvasOf(w, h)
    blurB = canvasOf(w, h)
    if not (frost and blurA and blurB) then
      frost, blurA, blurB, frostW, frostH = nil, nil, nil, 0, 0
      return nil
    end
    frostW, frostH = w, h
  end

  local prevCanvas = love.graphics.getCanvas()
  love.graphics.push('all')
  love.graphics.origin()
  love.graphics.setScissor()
  love.graphics.setShader()
  local prevBlend, prevAlpha = love.graphics.getBlendMode()
  local prevFilter = { src:getFilter() }
  src:setFilter("linear", "linear")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setBlendMode("replace", "premultiplied")

  local ok = pcall(function()
    love.graphics.setCanvas(frost)
    love.graphics.draw(src, 0, 0, 0, w / sw, h / sh)
    if blur then
      love.graphics.setShader(blur)
      love.graphics.setCanvas(blurA)
      pcall(blur.send, blur, "dir", { 2.5 / w, 0 })
      love.graphics.draw(frost)
      love.graphics.setCanvas(blurB)
      pcall(blur.send, blur, "dir", { 0, 2.5 / h })
      love.graphics.draw(blurA)
      love.graphics.setShader()
      frost, blurB = blurB, frost   -- the blurred one is the frost now
    end
  end)

  love.graphics.setShader()
  if prevCanvas then
    love.graphics.setCanvas(prevCanvas)
  else
    love.graphics.setCanvas()
  end
  love.graphics.setBlendMode(prevBlend or "alpha", prevAlpha)
  src:setFilter(prevFilter[1] or "nearest", prevFilter[2] or "nearest")
  love.graphics.pop()
  return ok and frost or nil
end

-- The same map for a rect that is ALREADY in world-canvas pixels. A HUD
-- snapped out to the window's edge has left the GB frame, so it has no GB
-- coordinates to be placed from -- see OverworldBattle.snapRects.
local function frostRectWorld(rect, box)
  local kx = frostW / box.pw
  local ky = frostH / box.ph
  return rect[1] * kx, rect[2] * ky,
         math.max(1, rect[3] * kx), math.max(1, rect[4] * ky)
end

-- Rectangle and source dimensions use the final window's coordinate space.
function BattleGlass.panel(rect, box)
  if not (frost and box and box.scale and box.scale > 0) then return false end
  local fx, fy, fw, fh = frostRectWorld(rect, box)
  local ok = pcall(function()
    local quad = love.graphics.newQuad(fx, fy, fw, fh, frostW, frostH)
    love.graphics.setColor(1, 1, 1, BattleGlass.FROST)
    love.graphics.draw(frost, quad, rect[1], rect[2], 0,
                       rect[3] / fw, rect[4] / fh)
    love.graphics.setColor(1, 1, 1, BattleGlass.TINT)
    love.graphics.rectangle("fill", rect[1], rect[2], rect[3], rect[4])
    love.graphics.setColor(1, 1, 1, 1)
  end)
  return ok
end

function BattleGlass.invalidate()
  frost, blurA, blurB = nil, nil, nil
  frostW, frostH = 0, 0
end
return BattleGlass
