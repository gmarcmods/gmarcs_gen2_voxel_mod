local source = debug.getinfo(1, "S").source:sub(2)
local test_dir = source:match("^(.*)/")
local module_path = test_dir .. "/../lib/CanvasOrientation.lua"

local function equal(actual, expected, message)
  assert(actual == expected, (message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function load_for(os_name, major, bound_canvas)
  local calls = {}
  local canvas = { getHeight = function() return 80 end }
  if bound_canvas == true then bound_canvas = canvas end
  local graphics = {
    draw = function(...) calls[#calls + 1] = { "draw", ... } end,
    push = function(...) calls[#calls + 1] = { "push", ... } end,
    pop = function(...) calls[#calls + 1] = { "pop", ... } end,
    translate = function(...) calls[#calls + 1] = { "translate", ... } end,
    scale = function(...) calls[#calls + 1] = { "scale", ... } end,
    getCanvas = function() return bound_canvas end,
  }
  _G.love = {
    system = { getOS = function() return os_name end },
    getVersion = function() return major, 0, 0 end,
    graphics = graphics,
  }
  local module = assert(loadfile(module_path))()
  return module, calls, canvas
end

local cases = {
  { "iOS", 11, false }, { "iOS", 12, true },
  { "Android", 12, false }, { "Linux", 12, false },
}
for _, case in ipairs(cases) do
  local module = load_for(case[1], case[2])
  equal(module.mirrors(), case[3], case[1] .. " " .. case[2] .. " mirror detection")
end

do
  local module, calls, canvas = load_for("iOS", 12)
  module.draw(canvas, 7, 11, 2, 3)
  local draw = calls[1]
  equal(draw[1], "draw")
  equal(draw[2], canvas)
  equal(draw[3], 7)
  equal(draw[4], 251, "mirrored origin accounts for scaled canvas height")
  equal(draw[5], 0)
  equal(draw[6], 2)
  equal(draw[7], -3)
  for i = #calls, 1, -1 do calls[i] = nil end
  module.draw(canvas, 7, 11)
  draw = calls[1]
  equal(draw[3], 7)
  equal(draw[4], 91)
  equal(draw[6], 1)
  equal(draw[7], -1)
end

do
  local module, calls = load_for("iOS", 12, true)
  local value = module.withRawFx(function() calls[#calls + 1] = { "fn" }; return 42 end)
  equal(value, 42)
  equal(calls[1][1], "push")
  equal(calls[1][2], nil, "transform-only push preserves the current canvas")
  equal(calls[2][1], "translate")
  equal(calls[2][2], 0)
  equal(calls[2][3], 80)
  equal(calls[3][1], "scale")
  equal(calls[3][2], 1)
  equal(calls[3][3], -1)
  equal(calls[4][1], "fn")
  equal(calls[5][1], "pop")

  for i = #calls, 1, -1 do calls[i] = nil end
  local ok, err = pcall(function()
    module.withRawFx(function() error("fx exploded") end)
  end)
  equal(ok, false)
  assert(tostring(err):find("fx exploded", 1, true))
  equal(calls[#calls][1], "pop", "graphics state is restored after callback error")
end

do
  local module, calls = load_for("iOS", 12, nil)
  local hit = false
  module.withRawFx(function() hit = true end)
  equal(hit, true)
  equal(#calls, 0, "unbound canvas passes through without transform calls")
end

do
  local module, calls, canvas = load_for("Android", 12)
  module.draw(canvas, 7, 11, 2, 3)
  equal(calls[1][4], 11, "non-mirrored draw keeps its origin")
  equal(calls[1][6], 2, "non-mirrored draw keeps positive horizontal scale")
  equal(calls[1][7], 3, "non-mirrored draw keeps positive vertical scale")
end

print("Canvas orientation tests passed")
