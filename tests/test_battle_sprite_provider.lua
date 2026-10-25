local root = arg[1] or "mods/gen2/new_mod_ex"
local calls, providers = {}, {}
love = love or { graphics = {} }
love.graphics = love.graphics or {}
local V = {}
local setting
V.require = function(name)
  assert(name == "ModSetting", "unexpected dependency: " .. tostring(name))
  return { new = function(_,_,values,labels)
    setting = { value = "native",values=values,labels=labels }
    function setting:get() return self.value end
    function setting:setGate() return self end
    return setting
  end }
end
V.mod = { find = function(id)
  local provider = providers[id]
  return provider and { exports = provider } or nil
end }
local BattleSprites = assert(loadfile(root .. "/lib/BattleSprites.lua"))(V)

local function provider(id, frameFn)
  local p = {
    apiVersion = 2,
    capabilities = { contract = "national-dex-battle-sprites",
      sources = { gen5_bw = true, gen5_b2w2 = true } },
    frame = frameFn or function(request)
      calls[#calls + 1] = request
      return { image = "image-" .. id, width = 10, height = 12 }
    end,
    status = function(source) return { ready = source ~= "missing" } end,
  }
  providers[id] = p
  return p
end
local p = provider("sprite_provider")
assert(BattleSprites.setting, "setting is exposed")
assert(BattleSprites.register("gen5_bw", "Black / White", p))
assert(not BattleSprites.register("gen5_b2w2", "Black 2 / White 2", p))

local mon = { species = "PIKACHU", shiny = true, gender = "female" }
local state = {
  game = { data = { pokemon = { PIKACHU = { dex = 25 } } } },
  activeMon = function(_, side) return side == "player" and mon or mon end,
}
local front = BattleSprites.frame(state, "player")
assert(front == nil and #calls == 0, "native setting does not query providers")
BattleSprites.setting.value = "gen5_bw"
front = BattleSprites.frame(state, "player")
assert(front and front.image == "image-sprite_provider", "valid provider frame is returned unchanged")
local request = calls[#calls]
assert(request.dex == 25 and request.side == "front", "national dex and front side are passed")
assert(request.source == "gen5_bw", "selected source is passed")
assert(request.shiny == true and request.gender == "female" and request.mon == mon,
       "mon appearance and identity are passed")
assert(request.battleId == state and request.battlerId == "player",
       "battle and player slot identity are passed")
local enemy = BattleSprites.frame(state, "enemy")
assert(enemy and calls[#calls].side == "front", "enemy 3D actor requests front-facing artwork")
assert(calls[#calls].battlerId == "enemy", "enemy slot identity is passed")

-- Trainer displays and Unown use their native/cutout path, with no provider call.
local count = #calls
state.showEnemyTrainer = true
assert(BattleSprites.frame(state, "enemy") == nil and #calls == count)
state.showEnemyTrainer = nil
state.showPlayerTrainer = true
assert(BattleSprites.frame(state, "player") == nil and #calls == count)
state.showPlayerTrainer = nil
mon.species = "UNOWN"
assert(BattleSprites.frame(state, "player") == nil and #calls == count)
mon.species = "PIKACHU"
state.game.data.pokemon.PIKACHU.dex = 201
assert(BattleSprites.frame(state, "player") == nil and #calls == count)
state.game.data.pokemon.PIKACHU.dex = 25

-- Missing source, provider failures, malformed dimensions, and unknown species
-- all preserve the native renderer without throwing.
BattleSprites.setting.value = "gen5_b2w2"
local b2 = BattleSprites.frame(state, "player")
assert(b2 == nil, "removed B2W2 source uses native artwork")
BattleSprites.setting.value = "unsupported"
assert(BattleSprites.frame(state, "player") == nil)
BattleSprites.setting.value = "gen5_bw"
local originalFrame = p.frame
p.frame = function() error("provider failure") end
assert(BattleSprites.frame(state, "player") == nil, "provider exceptions fall back")
p.frame = function() return { image = "bad", width = 0, height = 12 } end
assert(BattleSprites.frame(state, "player") == nil, "malformed dimensions fall back")
p.frame = originalFrame
mon.species = "UNKNOWN_SPECIES"
assert(BattleSprites.frame(state, "player") == nil, "unknown species is harmless")

-- withFrame temporarily redirects the native picture accessors while keeping
-- drawPic's original transform path around the larger provider artwork.
local g = love.graphics
local oldGraphics = { push = g.push, pop = g.pop, translate = g.translate }
local transforms = {}
local function resetTransforms() transforms = { { x = 0, y = 0 } } end
local function topTransform() return transforms[#transforms] end
g.push = function()
  local t = topTransform()
  transforms[#transforms + 1] = { x = t.x, y = t.y }
end
g.pop = function() assert(#transforms > 1, "graphics transform stack underflow"); transforms[#transforms] = nil end
g.translate = function(x, y)
  local t = topTransform(); t.x, t.y = t.x + x, t.y + y
end

BattleSprites.setting.value = "gen5_bw"
local largeImage = { tag = "large-provider-image" }
p.frame = function(request)
  calls[#calls + 1] = request
  return { image = largeImage, width = 77, height = 68 }
end
local nativeCalls = {}
state.pic = function(_, m, back)
  nativeCalls[#nativeCalls + 1] = { "pic", m, back }
  return "native-image", false, "native-path"
end
state.frontAnimFrame = function(_, m)
  nativeCalls[#nativeCalls + 1] = { "frontAnimFrame", m }
  return 3
end
state.picScale = function(_, path, m, back)
  nativeCalls[#nativeCalls + 1] = { "picScale", path, m, back }
  return 1
end
state.drawPic = function(_, m, back)
  nativeCalls[#nativeCalls + 1] = { "drawPic", m, back }
  return "native-draw"
end
local originalMethods = { state.pic, state.frontAnimFrame, state.picScale, state.drawPic }
local expectedScale = math.min(1, 56 / 77, 56 / 68)
mon.species = "PIKACHU"
resetTransforms()
local callbackResult = BattleSprites.withFrame(state, "player", function()
  local image, trueColor, path = state:pic(mon, false)
  assert(image == largeImage and trueColor == true and path == "provider/gen5_bw",
         "provider image temporarily replaces native picture")
  assert(state:frontAnimFrame(mon) == nil, "provider frame suppresses native front animation")
  assert(math.abs(state:picScale("provider/gen5_bw", mon, false) - expectedScale) < 1e-12,
         "oversized image is scaled to the battle box")
  state:drawPic({ species = "OTHER" }, false)
  assert(nativeCalls[#nativeCalls][1] == "drawPic", "other actors retain native drawPic")
  return "draw-complete"
end)
assert(callbackResult == "draw-complete")
assert(state.pic == originalMethods[1] and state.frontAnimFrame == originalMethods[2]
  and state.picScale == originalMethods[3] and state.drawPic == originalMethods[4],
  "all four patched methods restore after success")

-- Active-mon drawing reaches the original drawPic under the centering offset.
local translated
state.drawPic = function(_, m, back)
  nativeCalls[#nativeCalls + 1] = { "drawPic", m, back }
  translated = { topTransform().x, topTransform().y }
end
local drawPicOriginal = state.drawPic
resetTransforms()
BattleSprites.withFrame(state, "player", function() state:drawPic(mon, false) end)
assert(translated and translated[1] == -math.floor((77 - 56) / 2)
  and translated[2] == -(68 - 56), "large provider art is centered with native drawPic")
assert(#transforms == 1, "drawPic leaves graphics stack balanced")
assert(state.drawPic == drawPicOriginal, "drawPic restores after centered draw")

local successMethods = { state.pic, state.frontAnimFrame, state.picScale, state.drawPic }
local ok = pcall(function()
  BattleSprites.withFrame(state, "player", function() error("expected callback error") end)
end)
assert(not ok, "withFrame propagates callback errors")
assert(state.pic == successMethods[1] and state.frontAnimFrame == successMethods[2]
  and state.picScale == successMethods[3] and state.drawPic == successMethods[4],
  "all four patched methods restore after callback error")

local failingDraw = function() error("expected native draw error") end
state.drawPic = failingDraw
local drawErrorMethods = { state.pic, state.frontAnimFrame, state.picScale, state.drawPic }
resetTransforms()
ok = pcall(function()
  BattleSprites.withFrame(state, "player", function() state:drawPic(mon, false) end)
end)
assert(not ok, "native drawPic errors propagate")
assert(#transforms == 1, "drawPic balances graphics stack after an error")
assert(state.pic == drawErrorMethods[1] and state.frontAnimFrame == drawErrorMethods[2]
  and state.picScale == drawErrorMethods[3] and state.drawPic == drawErrorMethods[4],
  "all four methods restore after native drawPic errors")

-- Native setting takes the callback directly and does not call the provider or
-- replace any of the native accessors.
BattleSprites.setting.value = "native"
local beforeCalls = #calls
local nativeMethods = { state.pic, state.frontAnimFrame, state.picScale, state.drawPic }
assert(BattleSprites.withFrame(state, "player", function()
  assert(state.pic == nativeMethods[1] and state.frontAnimFrame == nativeMethods[2]
    and state.picScale == nativeMethods[3] and state.drawPic == nativeMethods[4],
    "native setting does not patch picture methods")
  return 42
end) == 42)
assert(#calls == beforeCalls, "native setting does not query provider")

g.push, g.pop, g.translate = oldGraphics.push, oldGraphics.pop, oldGraphics.translate

print("BATTLE SPRITE PROVIDER PASS")
