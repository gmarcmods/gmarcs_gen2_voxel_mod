-- Gen 2 Voxel Mod: a full 3D diorama overworld, shipped as a
-- rendering pipeline mod.
--
-- The engine's render_pipelines registry (src/mods/Schemas.lua) lets a mod
-- own part of the frame.  This mod registers two:
--
--   voxel      a drawWorld pipeline.  Instead of the flat tile blit, the
--              overworld's terrain is extruded into real geometry, walked
--              by a depth-buffered 3D camera, with characters as leaning
--              sprite slabs and a shadow map throwing real cast shadows
--              across whatever they land on.  Occlusion is the depth
--              buffer, not a y-sort: walk behind a building and the
--              building is simply in front.
--
--   tiltshift  a worldPresent pipeline -- the stage that post-processes
--              the finished world BEFORE the UI composites over it.  A
--              tilt-shift blur that sells the miniature-model look, on the
--              diorama only, leaving text boxes and menus crisp.
--
-- Everything a display mode needs beyond the two draw functions -- the
-- OFF/15/35/50 ladder, the options rows, the hotkeys, persistence in
-- save.options.pipelines, the free-roam gate, the mutual exclusion with
-- the engine's TILT mode -- is engine plumbing driven by the records
-- below.  This file declares; lib/ draws.
--
-- Voxel mode is presentational: it changes what the world LOOKS like and
-- nothing about what it IS.  TWO rungs are the deliberate exception. 1ST
-- (the camera in the player's own eyes) and 3RD (the same rig, boomed back
-- behind their shoulder) replace the grid WALK with a free,
-- camera-relative one while either is selected (lib/FreeMove.lua), because
-- a camera you can steer with a mouse demands feet that go where it looks.
-- Even there the game is untouched: the walk asks the engine's own
-- collision the same questions a grid step asks, keeps the player's
-- logical cell synced, and fires the engine's own landing pipeline per
-- cell crossed -- warps, encounters, ledges, gates and scripts all run
-- exactly as themselves. Step off the rung and the grid walk is back.

local mod = ...

-- ------- the mod namespace
--
-- lib/ modules require each other through V rather than package.path: a
-- mod directory is not on it, and may live inside a mounted .love archive
-- that plain require cannot reach.  Each module is loaded once, with V
-- passed in as its vararg (`local V = ...`).

local V = { mod = mod, path = mod.path }

local function chunkFor(rel)
  local source = mod:read(rel)
  if not source then
    error(("GEN2_VOXEL: %s is missing -- reinstall the mod"):format(rel), 0)
  end
  local chunk, err = load(source, "@" .. mod.path .. "/" .. rel)
  if not chunk then
    error(("GEN2_VOXEL: %s did not compile: %s"):format(rel, tostring(err)), 0)
  end
  return chunk
end

local modules = {}
function V.require(name)
  local hit = modules[name]
  if hit ~= nil then return hit end
  local value = chunkFor("lib/" .. name .. ".lua")(V)
  modules[name] = value
  return value
end

local dataFiles = {}
local profileExtensions
local function rawData(name)
  local hit = dataFiles[name]
  if hit == nil then hit=chunkFor("data/" .. name .. ".lua")(V);dataFiles[name]=hit end
  return hit
end
function V.data(name)
  if name=='voxel_heights'and profileExtensions then return profileExtensions:current()end
  return rawData(name)
end

-- ------- pipelines

local Voxel = V.require("VoxelState")
local Voxel3D = V.require("Voxel3D")
local VoxelScene = V.require("VoxelScene")
local TiltShift = V.require("TiltShift")
local ChunkMesher = V.require("ChunkMesher")
local VoxelGrid = V.require("VoxelGrid")
local WorldCurve = V.require("WorldCurve")
local DayNight = V.require("DayNight")
local DayTint = V.require("DayTint")
local Water = V.require("Water")
local ForestAtmos = V.require("ForestAtmos")
local AntiAlias = V.require("AntiAlias")
local FirstPerson = V.require("FirstPerson")
local FreeMove = V.require("FreeMove")
local CamControl = V.require("CamControl")

-- Forward declaration: the voxel pipeline's update hook (registered below)
-- calls this, and it is defined further down with the settings it drives.
-- Declared rather than left global -- a mod writing to _G would leak into
-- every other mod's namespace.
local applyFull

-- The last VOID FILL the terrain was meshed under; see the update hook.
-- The scene canvas's size, in FRAMEBUFFER PIXELS.
--
-- `ctx.width/height` are the window measured in LOVE UNITS
-- (love.graphics.getDimensions), but the engine composites a pipeline's
-- returned canvas with `draw(canvas, 0, 0, 0, 1/dpiX, 1/dpiY)` -- a scale
-- that only covers the window when the canvas is at PIXEL resolution.
-- Sizing it in units costs the DPI scale TWICE: the canvas is that much
-- smaller, then it is drawn that much smaller again, so the diorama lands
-- in the top-left corner at 1/dpi of the screen.  Desktop never sees it --
-- units and pixels are the same thing there -- but on Android the DPI scale
-- is the display density (2.625 on a 420dpi panel), and the world came out
-- a third of the size in each direction.
--
-- So ask for the pixel dimensions rather than trusting the ctx.  That is
-- the number a fixed engine would hand over, so this keeps working either
-- way instead of double-correcting.  It also squares the FX pass: ctx.scale
-- is ALREADY in pixels per world pixel (Zoom.scale over Renderer:fitScale,
-- which measures the drawable), so the closures ctx.drawFx runs were being
-- scaled for a canvas 2.6x bigger than the one they drew into.
local function sceneSize(ctx)
  if ctx.pixelWidth and ctx.pixelHeight then
    return ctx.pixelWidth, ctx.pixelHeight
  end
  if love.graphics and love.graphics.getPixelDimensions then
    local pw, ph = love.graphics.getPixelDimensions()
    if pw and ph and pw > 0 and ph > 0 then return pw, ph end
  end
  return ctx.width, ctx.height
end

local voidFill = { last = nil }
function voidFill.check()
  local TileRenderer = require("src.render.TileRenderer")
  local now = TileRenderer.voidFill
  if voidFill.last ~= nil and now ~= voidFill.last then
    ChunkMesher.invalidate()   -- no map id: every ring on every map is stale
  end
  voidFill.last = now
end

mod.content.render_pipelines:register("voxel", {
  label = "VOXEL",
  levels = Voxel.ANGLE_LABELS,
  -- 3 is the engine's TILT key, which this mode supersedes -- see the
  -- hotkey block near the bottom of this file for how it is claimed
  hotkey = "3",
  -- above tiltshift, so the two sort together in the options list with the
  -- mode first and its post-process under it
  priority = 20,

  -- Headless runs and drivers without a depth canvas or shader support
  -- answer false here, and the engine keeps the vanilla 2D path -- which
  -- is why no caller ever has to guard for a missing 3D pass.
  available = function()
    return Voxel3D.available()
  end,

  -- the engine hands over the live level; we ease the camera toward it.
  -- pump() advances queued mesh builds inside a few-millisecond budget,
  -- so entering voxel mode (and streaming neighbours while walking)
  -- costs frames nothing visible -- the old synchronous build froze the
  -- first frame for seconds. prefetch() runs here as well as in the
  -- draw, because update ticks even while a warp's Transition covers
  -- the screen: the destination's meshes start building the moment the
  -- map swaps behind the fade, and the fade-covered frames get a wider
  -- pump slice -- so stepping out of a door lands on terrain that is
  -- already there instead of a flat flash.
  update = function(dt, level)
    -- FULL is a preset, so it is applied ON THE PRESS rather than held every
    -- frame: it SETS the other rows and then leaves them alone. Holding them
    -- would make the zoom keys and the wheel dead while the mode was on, and
    -- would fight anyone who changed one deliberately.
    applyFull(level)
    Voxel.update(dt, level)
    -- the first-person head, on the same tick: its blend in and out of the
    -- orbit, the mouse capture lifecycle, and the frame's stick-rate look.
    -- Unconditional like Voxel.update, because the blend has to keep easing
    -- OUT after the rung is left
    FirstPerson.update(dt)
    -- the day/night clock, on the same always-running tick: Pipelines.update
    -- runs whatever the level, so time passes with the mode off, through
    -- battles and menus, and a CYCLE evening falls mid-fight exactly as it
    -- would mid-walk
    DayNight.update(dt)
    -- the atmosphere's own clock (shaft shimmer, drifting motes), on the
    -- same tick so the beams keep breathing through a dialog box
    ForestAtmos.update(dt)
    -- VOID FILL picks the block the border ring is made of, and in this
    -- mode that ring is BAKED INTO THE MESH rather than drawn each frame.
    -- So the option has to reach the cache or nothing happens on screen
    -- until the meshes are dropped for some other reason -- which reads
    -- exactly like the option doing nothing at all. Polled rather than
    -- hooked because the engine changes it from three places (the options
    -- row, applyOptions on load, TileRenderer.setVoidFill) and none of
    -- them announces it. Ahead of the active() gate, so switching it
    -- while voxel mode is OFF still invalidates what is cached.
    voidFill.check()
    if not Voxel.active() then return end
    local Game = require("src.core.Game")
    local ow = Game and (Game.overworld or Game.world)
    if ow and ow.map and ow.camera then
      pcall(VoxelScene.prefetch, ow)
    end
    ChunkMesher.pump(Game and Game.stack
                     and Game.stack:top() ~= ow)
  end,

  drawWorld = function(ctx)
    -- All nested scene/FX canvases use framebuffer pixels. The pipeline's
    -- engine guard restores the caller's transform and scissor afterward.
    love.graphics.origin()
    love.graphics.setScissor()
    -- Terrain and characters are geometry; the field FX stay ordinary 2D
    -- draws composited on top, anchored through the same camera the 3D
    -- pass used (ctx.drawFx below).  The scene renders at the window's
    -- PIXEL resolution (see sceneSize) so the 3D pass is crisp rather than
    -- a magnified low-res image, while the FX closures keep drawing in
    -- world-pixel units.
    local sw, sh = sceneSize(ctx)
    -- With AA on, the whole pass runs into a canvas BIGGER than the window
    -- and is folded back down at the end (see AntiAlias).  Nothing between
    -- these two lines knows: every pass in the frame measures itself in the
    -- canvas it was handed, so the sky's dither, the water's march and the
    -- camera itself all come out the same picture at a higher sample rate.
    local rw, rh = AntiAlias.expand(sw, sh)
    local canvas = VoxelScene.render(ctx.state, rw, rh,
                                     ctx.vw, ctx.vh, ctx.paletteFor)
    if not canvas then return nil end   -- fall back to the 2D path
    if Voxel3D.beginOverlay() then
      -- the FX closures are ordinary 2D draws sized in DISPLAY pixels, and
      -- they are drawing into the supersampled canvas alongside everything
      -- else -- so the scale goes up with it, or the "!" bubble lands the
      -- right place at half the size.  project() already answers in canvas
      -- pixels, so only the scale needs saying.
      ctx.drawFx(function(wx, wz, height) return Voxel3D.project(wx, height or 0, wz) end,
                 ctx.scale * AntiAlias.factor())
      Voxel3D.endOverlay()
    end
    -- and back to the window's own size, which is what the engine composites
    -- one canvas pixel to one display pixel.  A pass-through when AA is off.
    return AntiAlias.resolve(canvas, sw, sh, "world")
  end,

  invalidate = function()
    Voxel3D.invalidate()
    AntiAlias.invalidate()
    ChunkMesher.invalidate()   -- no map id = every cached mesh
    ForestAtmos.invalidate()   -- shaft/particle meshes and shader sentinels
  end,
})

mod.content.render_pipelines:register("tiltshift", {
  label = "T-SHIFT",
  levels = TiltShift.LABELS,
  -- 6 is free: no engine branch claims it, so this one alone reaches the
  -- registry by the documented route
  hotkey = "6",
  priority = 10,

  update = function(dt, level)
    TiltShift.update(dt, level)
  end,

  -- worldPresent, not present: the blur belongs on the diorama, not on the
  -- dialog box in front of it.  A pass-through when the level is 0 or the
  -- shader is unavailable, so the frame is untouched in every other case.
  worldPresent = function(canvas)
    return TiltShift.apply(canvas)
  end,

  invalidate = function()
    TiltShift.invalidate()
  end,
})

-- ------- this mod's own settings
--
-- Neither of these is a pipeline: they own no pass of the frame, they
-- PARAMETERISE the voxel one, so they have nothing to put in drawWorld or
-- present and the registry would rightly reject them.  Plain mod settings
-- instead -- see ModSetting for where they persist and how the two rows
-- each ends up on stay in step.

-- ------- the FULL preset
--
-- Everything the mode wants switched to at once. Applied when the VOXEL row
-- ARRIVES at FULL and not again, so the player can still move the camera or
-- the zoom afterwards -- it is a starting point, not a lock.
--
-- Leaving FULL deliberately does NOT undo any of it. A preset that reverted
-- would throw away whatever the player had changed since, and "put it back
-- how it was" is not a thing this can know.
local fullWas = nil

applyFull = function(level)
  local isFull = Voxel.isFull(level)
  local was = fullWas
  fullWas = isFull
  if not isFull or was == true or was == nil then return end

  local Game = require("src.core.Game")
  local Pipelines = require("src.render.Pipelines")
  local Zoom = require("src.render.Zoom")
  local opts = Game.save and Game.save.options
  if not opts then return end

  -- the miniature blur at its strongest: FULL is the diorama look, and the
  -- tilt-shift is most of what makes it read as a model
  Pipelines.setLevel("tiltshift", Pipelines.maxLevel("tiltshift"))
  Pipelines.syncOptions(opts)
  -- the horizon flat. The curve bends the world away from a walking player,
  -- which fights a fixed diorama framing
  WorldCurve.setting:setIndex(1, Game)
  -- and the water reflecting everything it can: FULL is the diorama at its
  -- most photographed, and a lake with the sky and the shoreline in it is
  -- most of what makes the model read as being outdoors
  Water.setting:setIndex(1, Game)
  -- and the view fitted to the window
  opts.zoom = 0
  Zoom.applyOptions(opts)
  -- and the sky on the clock on the wall: FULL pins DAYTIME to SYNC. Unlike
  -- the rest of the preset this one IS held, not just set -- the row is off
  -- the menu while FULL owns it (the rows hook below), so a value changed
  -- under it could never be seen or changed back.
  DayNight.forceSync(Game)
  if Game.writeOptions then pcall(Game.writeOptions, Game) end
end

local SETTINGS = {
  { VoxelGrid.setting, "One-pixel wireframe along every voxel edge." },
  { WorldCurve.setting,
    "Bend the world down over the horizon, Animal Crossing style." },
  { Water.setting,
    "Reflections on water. FULL adds screen-space reflections of the "
    .. "shoreline, the trees and the buildings behind it; SKY is the sky, "
    .. "the sun and the moon alone, which is most of the look for a "
    .. "fraction of the cost." },
  -- `full` for the AA reason: additive shafts are fill rate, and under 4X
  -- supersampling that is a question about the hardware, not the look.
  { ForestAtmos.setting,
    "The air of the deep woods: a ground haze, and "
    .. "volumetric light let down through the unseen canopy overhead -- "
    .. "gold spears of sun by day, silver moon rays at night, pollen "
    .. "drifting through the beams and fireflies once they cool. LOW "
    .. "keeps the haze, halves the beam march and stands the particles "
    .. "down. On a phone the row offers LOW alone: the beams need a "
    .. "depth texture the pass can read back, and no mobile driver here "
    .. "grants one.",
    full = true },
  { DayNight.setting,
    "What time it is outdoors: pin the sky to DAY, NIGHT, DUSK or DAWN, "
    .. "let CYCLE run it -- ten minutes of sun, ten of moon, with the "
    .. "shadows, the sky and the light following -- or SYNC it to the "
    .. "clock on the wall, so the game's evening falls when yours does." },
  -- Marked `full` for the opposite reason the battle rows are: this is not a
  -- knob on the look at all, it is what the look COSTS. FULL is a preset for
  -- the diorama, not a licence to spend four times the fill rate on the
  -- machine it happens to be running on, so it neither sets this nor takes
  -- the row away -- the player decides what their hardware can carry, from
  -- inside FULL like anywhere else.
  { AntiAlias.setting,
    "Smooth the stair-stepped edges of the 3D world -- roof ridges, ledge "
    .. "lips, a tree against the sky -- by rendering the diorama larger than "
    .. "the window and folding it back down. Every edge in the picture "
    .. "softens with them, the tileset's own texels included, so the diorama "
    .. "reads smoother rather than sharper. 2X costs half again as many "
    .. "pixels in each direction and 4X twice, which makes this the most "
    .. "expensive row in the mod.",
    full = true },
}

SETTINGS[#SETTINGS+1]={V.require('GoldBattle').setting,
 'Stage battles on the MAP or on PLATFORMS. Installed model packs enable STADIUM A/B. OFF uses the classic battle screen.',
 full=true}
SETTINGS[#SETTINGS+1]={V.require('BattleSprites').setting,
 'Optional imported battle artwork. Install the Gen 5 sprite provider and import your own ROM through IMPORTERS. Missing artwork uses native sprites.',full=true}
local StadiumImport=V.require('StadiumImport')
StadiumImport.restore()
function V.refreshSettings()
  local schema={}
  for _,entry in ipairs(SETTINGS)do schema[#schema+1]=entry[1]:schema(entry[2])end
  mod.options:define(schema)
end
V.refreshSettings()

-- ------- this mod's hotkeys
--
--   3  VOXEL    cycle the camera ladder      (was 6; skips FULL)
--   5  V-GRID   toggle the wireframe         (new)
--   6  T-SHIFT  cycle the blur ladder        (was 9)
--   7  V-CURVE  cycle the horizon bend       (new)
--   9  WATER    cycle the water reflections  (new; 9 was T-SHIFT's old key)
--
-- Only 6 arrives by the documented route. Game:keypressed answers the
-- engine's own display keys FIRST and returns -- 2 COLORS, 3 TILT, 4 ZOOM,
-- 5 GBC FX -- and only then offers the key to Pipelines.hotkey, expressly
-- so "a pipeline can never shadow one" (Schemas, render_pipelines.hotkey).
-- 3 and 5 are two of those, and 7 and 8 belong to plain mod settings that
-- own no pass and so have no registry to claim a key from at all.
--
-- So this wraps Game:keypressed. It is the invasive option and it is the
-- only one: polling the keyboard in update() would fire alongside the
-- engine's handler rather than instead of it, so 3 would cycle this mode
-- AND the engine's TILT on the same press.
--
-- Consequences worth being explicit about: while this mod is enabled, TILT
-- (3) and GBC FX (5) are unreachable by key -- and unreachable on the OPTIONS
-- menu too, where both rows are taken away and both values held at zero (see
-- pinEngineFx). Nothing is being hidden that still does something: TILT is the
-- flat fake of what this mode does for real, the registry already forces it
-- off whenever a world pipeline takes the pass, and GBC FX is a full-screen
-- present pass over the top of the diorama. Uninstalling puts both back.
--
-- Everything the engine does around a pipeline hotkey has to happen here
-- too, so the work is DELEGATED rather than reimplemented: Pipelines.hotkey
-- applies its own gate and ladder, and the three lines after it are the
-- engine's own (syncOptions, the tilt exclusion, writeOptions).

local HOTKEYS = {
  ["3"] = "pipeline",           -- voxel, by its declared hotkey
  ["6"] = "pipeline",           -- tiltshift, likewise
  ["5"] = VoxelGrid.setting,
  ["7"] = WorldCurve.setting,
  ["9"] = Water.setting,
}

-- One step of the VOXEL angle ladder: everything a "3" press does, named
-- so the pad's SELECT button (below) can make exactly the same step. The
-- gate is the registry's own; the tilt/GBC FX clearing is the engine work
-- the key has always delegated (see the wrap below for why).
local function clearLegacyGbcFx()
  -- New engine releases removed GBCFX in favour of shader presets. Older
  -- releases still need the old fullscreen effect switched off.
  local moduleName = "src.render.GBCFX"
  local fx = package.loaded[moduleName]
  if not fx then
    if love.filesystem and love.filesystem.getInfo
        and not love.filesystem.getInfo("src/render/GBCFX.lua") then
      return
    end
    local ok
    ok, fx = pcall(require, moduleName)
    if not ok then return end
  end
  if type(fx.setLevel)=="function" then fx.setLevel(0) end
end

local function cycleVoxel(game)
  local Pipelines = require("src.render.Pipelines")
  local top = game.stack and game.stack:top()
  if not Pipelines.canToggle("voxel", top, game.overworld) then return false end
  Pipelines.setLevel("voxel", Voxel.nextHotkeyLevel(Pipelines.level("voxel")))
  Pipelines.syncOptions(game.save.options)
  -- 3 is the key that used to turn TILT on and sits next to the one that
  -- used to turn GBC FX on, and this mod has taken both away. A player who
  -- left either running before enabling the mod would otherwise have no
  -- way back to off, and both fight the diorama -- so the VOXEL step
  -- clears them on EVERY press, not just the press that switches on.
  game.save.options.tilt = 0
  game.save.options.gbcfx = 0
  clearLegacyGbcFx()
  require("src.render.Tilt").setLevel(game.save.options.tilt or 0)
  game:writeOptions()
  return true
end

do
  local Game = require("src.core.Game")
  local Pipelines = require("src.render.Pipelines")
  local inner = Game.keypressed

  function Game:keypressed(key)
    local claim = HOTKEYS[key]
    local top = self.stack and self.stack:top()
    -- Q and E work for the third-person boom or the engine's own survey
    -- zoom on an orbit rung. CamControl answers which, and answers "none"
    -- for 1ST and for every screen with no camera of ours behind it, in
    -- which case the key falls through untouched. Ahead of the hotkey
    -- table because it is only useful while the overworld camera is active.
    if (key == "q" or key == "e")
       and not (top and top.onKeyPressed) then
      if CamControl.zoomBy(key == "q" and 1 or -1) then return end
    end
    -- A screen with its own key handler gets the key first, exactly as the
    -- engine's first branch does: typing a nickname must not toggle a
    -- render mode. Only free-roam presses are ours to take.
    if claim and not (top and top.onKeyPressed) then
      if claim == "pipeline" then
        -- 3 walks the ANGLE rungs and steps over FULL (Voxel.HOTKEY_ORDER),
        -- so the registry's plain "advance one and wrap" is not what it
        -- wants; 6 still is. The gate is the registry's own either way.
        -- The whole of 3's step lives in cycleVoxel, because the pad's
        -- SELECT button makes the same step (see the handleInput wrap).
        if key == "3" then
          if cycleVoxel(self) then return end
        elseif Pipelines.hotkey(key, top, self.overworld) then
          Pipelines.syncOptions(self.save.options)
          require("src.render.Tilt").setLevel(self.save.options.tilt or 0)
          self:writeOptions()
          return
        end
      elseif Pipelines.canToggle("voxel", top, self.overworld) then
        -- All four answer to the voxel pass's own free-roam gate --
        -- borrowed from the registry rather than restated, so a press
        -- mid-warp or mid-cutscene is refused for the wireframe exactly when
        -- it would be for the mode itself. Three of them parameterise that
        claim:cycle(self)
        return
      end
    end
    return inner(self, key)
  end
end

-- ------- the mode's rows, kept together
--
-- The engine splices a pipeline's row in beside TILT, because a display mode
-- belongs with the other display modes; a mod's own ui.options.rows
-- additions land at the END of the list. That left this mod's four rows in
-- two places with unrelated engine rows between them, which reads as two
-- unrelated features rather than one mode with settings.
--
-- So the plain settings are inserted directly after the last of this mod's
-- PIPELINE rows instead of appended. Nothing else moves: the block lands
-- where the engine already decided display modes go.
local function insertGrouped(out, extra)
  local anchor = nil
  for i, row in ipairs(out) do
    local id = type(row) == "table" and row.id
    if id == "pipeline:voxel" or id == "pipeline:tiltshift" then anchor = i end
  end
  if not anchor then
    for _, row in ipairs(extra) do out[#out + 1] = row end
    return out
  end
  for i, row in ipairs(extra) do table.insert(out, anchor + i, row) end
  return out
end

-- FULL owns the settings that describe the LOOK, so while it is selected those
-- are taken off the menu rather than left to be changed under it -- including
-- T-SHIFT, which is a pipeline row the engine put there. A row that no longer
-- decides anything is worse than no row.
--
-- The battle rows are the exception and they stay; see the rows hook.
local function dropRow(out, id)
  for i = #out, 1, -1 do
    if type(out[i]) == "table" and out[i].id == id then table.remove(out, i) end
  end
  return out
end

-- ------- TILT and GBC FX are gone while this mod is installed
--
-- Both fight the diorama, and both were already half-taken: the mode's own key
-- (3) forces them off on every press, and the registry switches TILT off
-- whenever a world pipeline takes the pass. What was left was two rows the
-- player could set and watch get reverted -- TILT is the flat fake of what
-- this mode does for real, and GBC FX is a full-screen present pass over the
-- top of the whole thing.
--
-- So they come OFF the menu, and are HELD at zero rather than merely dropped.
-- Hiding a live setting is a trap: a save written before the mod was installed
-- can carry TILT 3, and a row that is not there is a row that cannot turn it
-- back off. Pinned wherever the value could have arrived from -- the menu
-- opening, a save being loaded or begun -- so there is no route by which one
-- of them is on and unreachable.
--
-- Everything they did is still reachable: uninstall the mod and both rows are
-- back, at whatever they were last set to.
-- BATTLE BG rides the same reasoning, and comes off for a reason of its own.
-- The row picks what fills the screen AROUND the battle's 160x144 field --
-- WHITE paper, BLACK bars, or the frozen overworld dimmed behind it -- and
-- all three were answers to the same question: what to do with the voids,
-- given the battle is a small picture in the middle of a big window.
--
-- This mod answers that question differently and permanently. A staged fight
-- fills the whole window with the map the fight is standing on, and the
-- flat battle screen it composites over it is drawn on the mode's own
-- surface; there are no voids left for the row to fill. WORLD is the worst
-- of the three under it -- it makes the battle non-opaque so the engine
-- draws the overworld underneath, which is a SECOND copy of the world drawn
-- under the one the arena pass already put there, dimmed and at a different
-- camera. BLACK bars over a diorama read as a letterboxed screenshot.
--
-- So the value is pinned at WHITE, which is the one the mode was composed
-- against, and the row comes off the menu on the same reasoning as TILT and
-- GBC FX: a row that no longer decides anything is worse than no row.
-- Uninstall the mod and it is back, at whatever it was last set to.
local function pinEngineFx(game)
  game = game or require("src.core.Game")
  local opts = game and game.save and game.save.options
  local Tilt = require("src.render.Tilt")
  local changed = false
  if opts then
    changed = (opts.tilt or 0) ~= 0 or (opts.gbcfx or 0) ~= 0
                or (opts.battleBg or "white") ~= "white"
    opts.tilt, opts.gbcfx = 0, 0
    opts.battleBg = "white"
  end
  pcall(Tilt.setLevel, 0)
  clearLegacyGbcFx()
  if changed and game.writeOptions then pcall(game.writeOptions, game) end
end

-- call next() first and decorate what comes back, so every other mod's
-- rows survive this one
mod.hooks:wrap("ui.options.rows", function(next, game, rows)
  local out = next(game, rows)
  if type(out) ~= "table" then return out end
  local Pipelines = require("src.render.Pipelines")
  -- ahead of every branch below, including FULL's early return: these two are
  -- off the menu whatever else this mod is or is not doing
  pinEngineFx(game)
  dropRow(out, "tilt")
  dropRow(out, "gbcfx")
  -- and BATTLE BG with them: this mode fills the window with the map, so
  -- the row's whole question -- what to put in the voids around the battle
  -- -- no longer has voids to be about (see pinEngineFx)
  dropRow(out, "battleBg")
  -- On GEN 1 the engine splices the pipeline rows (VOXEL, T-SHIFT) into the
  -- OPTIONS screen itself, next to TILT (src/ui/OptionsMenu.lua buildRows).
  -- Gold's screen never built them -- the gen 2 menu is gen1recomp's own, and
  -- its row list holds only the cart's options -- so this mod supplies the
  -- same rows here, from the SAME descriptor the engine would: stepping one
  -- cycles the ladder and writes options.pipelines, which Game2:applyOptions
  -- restores on the next boot exactly as Game:applyOptions does on gen 1.
  --
  -- Gated on the engine rows being absent rather than on the generation, so
  -- a build that ever gains them (or a third generation that provides them)
  -- does not double the ladder up. Without a VOXEL row to anchor on, this
  -- mod's settings would still land -- appended instead of grouped -- but the
  -- mode would have no way to be turned on from the menu at all.
  local hasPipelineRow = false
  for _, row in ipairs(out) do
    if type(row) == "table" and row.id == "pipeline:voxel" then
      hasPipelineRow = true
      break
    end
  end
  if not hasPipelineRow then
    for _, row in ipairs(Pipelines.rows(game)) do
      out[#out + 1] = row
    end
  end
  local full = Voxel.isFull(Pipelines.level("voxel"))
  if full then
    -- FULL owns the rows that PARAMETERISE the diorama -- the wireframe, the
    -- horizon bend, the blur, the hour -- so those come off the menu and
    -- DAYTIME is held at SYNC while its row is unreachable.
    DayNight.forceSync(game)
    dropRow(out, "pipeline:tiltshift")
  end
  local extra = {}
  for _, entry in ipairs(SETTINGS) do
    -- Two things decide whether a row is offered.
    --
    -- FULL: a preset that owns the look, so the rows that describe the look go
    -- with it. The mod manager's page carries every one of them either way.
    local offered = (entry.full or not full)
                    and (not entry.when or entry.when())
    if offered then extra[#extra + 1] = entry[1]:row() end
  end
  extra[#extra+1]=StadiumImport.row()
  return insertGrouped(out, extra)
end)

-- The mod manager writes and persists on its own, so the only thing left
-- to do is move our cached index and pick the new value up.
mod.events:on("mod.options_changed", function(payload)
  if not (payload and payload.mod == mod.id) then return end
  for _, entry in ipairs(SETTINGS) do
    if payload.key == entry[1].key then entry[1]:sync(payload.value) end
  end
  -- and DAYTIME changed from the manager's page while FULL owns it snaps
  -- straight back to SYNC -- the OPTIONS row is hidden, but the manager's is
  -- not, and FULL's pin must hold against both
  local Pipelines = require("src.render.Pipelines")
  if Voxel.isFull(Pipelines.level("voxel")) then DayNight.forceSync() end
end)

-- ------- keeping the geometry in step with the world
--
-- Terrain meshes are derived from a map's block layer, so anything that
-- rewrites a block (a cut tree, a smashed rock, a script's replaceBlock)
-- has to drop that map's cached mesh or the 3D world keeps showing the
-- tree that is no longer there.  The 2D tile renderer invalidates its own
-- caches off the same edit.

-- refresh, not invalidate: the stale mesh keeps drawing while the
-- replacement builds in the background, so a one-block edit (Cut, a
-- door stamp, the tree regrowing on re-entry) repopulates in place
-- instead of blinking the whole scene down to the flat 2D path
mod.events:on("world.block_replaced", function(payload)
  local mapId = payload and (payload.mapId or (payload.map and payload.map.id))
  if mapId then
    local handled=V.require('LiveCutProps').handles(mapId,payload.bx,payload.by,payload.block)
    if not handled then ChunkMesher.refresh(mapId)end
    V.require("ShadowMap").invalidate()
  end
end)

V.require('WorldMeshSync').install(require('src.world.gen2.World'),function(world,edit)
  local def=world.maps and world.maps[edit.id]
  local width=def and def.width
  local zero=edit.index-1
  local handled=width and V.require('LiveCutProps').handles(edit.id,zero%width,math.floor(zero/width),edit.block)
  if not handled then ChunkMesher.refresh(edit.id)end
  ForestAtmos.invalidate(edit.id);V.require("ShadowMap").invalidate()
end)

-- The event above is the ANNOUNCED edit -- OverworldState:replaceBlock
-- emits it, which is the path Victory Road's barriers and a script's
-- replaceBlock take. Several edits do not go through it:
--
--   Cut          swaps the tree block and rebuilds the 2D renderer
--   the regrowth restores those blocks when the map is re-entered
--   card-key doors are stamped closed on floor load
--
-- all of them writing the block layer directly. Meshes derived from that
-- layer went stale with no announcement -- the cut tree stayed standing,
-- and after a round trip through a door the stump stayed cut because this
-- map's mesh survives in the cache (that is what prevLive is for).
--
-- The engine could announce each of those, and an earlier cut of this
-- work changed it to. That is the wrong place: it edits the game for one
-- mod's benefit, and every future path that writes a block has to
-- remember to do the same. They all funnel through ONE choke point --
-- Map:setBlock -- so wrap that from here instead. Map is a plain
-- metatable shared by every map instance, so this covers all of them,
-- including paths written after this mod.
--
-- Read back rather than trust the argument: setBlock silently ignores an
-- out-of-bounds write, and a stamp that rewrites a block with the value
-- it already held (the door code guards for this, the regrowth does not)
-- is not a change and must not throw the mesh away.
do
  local Map = require("src.world.Map")
  if not Map.gen2VoxelBlockHook then
    local setBlock = Map.setBlock
    Map.setBlock = function(self, bx, by, block)
      local before = self:blockAt(bx, by)
      setBlock(self, bx, by, block)
      if self.id and self:blockAt(bx, by) ~= before then
        ChunkMesher.refresh(self.id)
      end
    end
    Map.gen2VoxelBlockHook = true
  end
end

-- A reloaded map is rebuilt from scratch (warps that re-enter the same map,
-- hot reload), so its mesh is stale for the same reason -- with one
-- exception, and it is the common one.
--
-- A palette switch reloads the map ONLY to rebuild its atlas
-- (PaletteFX.setMode -> reloadMap(id, "colors")). The geometry that comes
-- back is identical: this mesher reads block layout and tile ids and never
-- reads colour, and the palette lives entirely in the texture TerrainAtlas
-- hands back per frame -- which is keyed BY palette, so the new colours are
-- already built by the time the next frame draws.
--
-- Dropping the mesh anyway cost a visible flash of the flat 2D world on
-- every palette toggle. Mesh builds are asynchronous, so the frames between
-- the drop and the first finished mesh have no terrain to draw, and
-- drawWorld returning nil IS the 2D fallback. Keeping the geometry lets the
-- new colours land on the diorama already on screen, in one frame, which is
-- what a palette toggle should look like from inside voxel mode.
mod.events:on("map.reloaded", function(payload)
  if payload and payload.reason == "colors" then return end
  local mapId = payload and (payload.mapId or (payload.map and payload.map.id))
  if mapId then ChunkMesher.invalidate(mapId) end
  -- the atmosphere's layout stands on the same carved stamps the meshes
  -- do, so it goes stale on exactly the same event
  if mapId then ForestAtmos.invalidate(mapId) end
end)

-- ------- rows come and go, so the menu has to notice
--
-- OptionsMenu builds its row list ONCE, when it is opened, and then reads
-- that list every frame. So stepping the VOXEL row onto or off FULL changed
-- which rows the hook would return but not which rows were on screen -- the
-- settings FULL owns stayed visible until the menu was closed and reopened,
-- and a player who stepped off FULL could not see the rows come back.
--
-- Rebuilt in place only when crossing FULL.
-- Every other rung returns the same list, and rebuilding on all of them would
-- rerun every mod's ui.options.rows hook once per keypress. The cursor is
-- clamped rather than reset, so it stays on the row it was just used on
-- instead of jumping to the top when the list below it shortens.
do
  local OptionsMenu = require("src.ui.OptionsMenu")
  if not OptionsMenu.gen2VoxelFullHook then
    local Pipelines = require("src.render.Pipelines")
    local inner = OptionsMenu.update

    local function idAt(menu, index)
      local row = menu.rows and menu.rows[index or 1]
      return type(row) == "table" and row.id or nil
    end

    function OptionsMenu:update(dt)
      local before = Pipelines.level("voxel")
      local wasOn = idAt(self, self.index)
      inner(self, dt)
      local after = Pipelines.level("voxel")
      local crossedFull = after ~= before
                          and (Voxel.isFull(before) or Voxel.isFull(after))
      if crossedFull then
        local rebuilt = OptionsMenu.new(self.game)
        self.rows = rebuilt.rows
        -- Follow the row the cursor was ON rather than the slot it was in.
        for i = 1, #self.rows do
          if wasOn and idAt(self, i) == wasOn then self.index = i; break end
        end
        local cancel = #self.rows + 1
        if (self.index or 1) > cancel then self.index = cancel end
      end
    end

    OptionsMenu.gen2VoxelFullHook = true
  end
end

-- ------- gold's world pass: the drawWorld seam the engine never built
--
-- Gen 1's engine hands the overworld to Pipelines.drawWorld every frame
-- (src/world/OverworldController.lua:4827); Gold's never does -- its
-- overworld draws flat (src/core/Game2.lua drawScene) and Game2:load
-- retires a stored world-pipeline level, because on Gold a drawWorld
-- pipeline would render nothing AND hold TILT off.  So the reachable,
-- engine-untouched way to give the voxel mode its pass on gold is to patch
-- it from here: gold's whole world draw is ONE call -- World:draw -- hit
    -- only from Game2:drawScene's plain-overworld tail,
-- both of which want the world rendered (a wipe that slides back to a 3D
-- world is what Gen 1 does behind its transitions).  The transform is
-- already set by the caller (frameWorldActive and the letterbox ran), so
-- when a world pipeline owns the pass this mod renders it through the
-- engine's own dispatch -- Pipelines.drawWorld over a ctx the engine would
-- have handed over on Gen 1 (built in lib/Gen2.lua worldCtx) -- and draws
-- the returned canvas in the flat world's place.  A pipeline that declines
-- a frame returns nil and the original flat draw runs: the same degrade the
-- Gen 1 path makes, so nothing can crash the frame short of the mod itself.
--
-- Patched only where the gen 2 module exists: on Gen 1 this whole block is
-- a no-op and the engine's own pipeline path keeps working untouched.
do
  local ok, World = pcall(require, "src.world.gen2.World")
  if ok and World and not World.gen2VoxelWorldDraw then
    local Pipelines = require("src.render.Pipelines")
    local inner = World.draw
    World.draw = function(self, ...)
      -- Only this mod's own world pipeline.  A cartridge could carry another
      -- drawWorld pipeline, and this ctx is built for the reads this mod's
      -- pass makes -- let its own call path (or the flat path) keep the frame.
      if Pipelines.worldPipeline() == "voxel" then
        local level = Pipelines.level("voxel")
        local ctx = V.require("Gen2").worldCtx(self, level, require("src.core.Game"))
        local override = Pipelines.drawWorld("voxel", ctx)
        if override then
          override = Pipelines.worldPresent(override, ctx) or override
        end
        if override then
          love.graphics.setColor(1, 1, 1, 1)
          V.require("CanvasOrientation").draw(override, 0, 0, ctx.presentScale, ctx.presentScale)
          return
        end
      end
      return inner(self, ...)
    end
    World.gen2VoxelWorldDraw = true
  end
end

-- The engine retires a stored world-pipeline level on boot because on Gold
-- it would draw nothing and would hold TILT off (src/core/Game2.lua load).
-- The patch above made that premise false, so a save that left the mode on
-- gets it back here: AFTER the retire, read from the same bucket applyOptions
-- already read (options.pipelines, which the retire deliberately left alone),
-- so the mode returns exactly where the player left it rather than as the
-- patch's default.  Only on gold -- on Gen 1 applyOptions already restored
-- it and re-setting the same level would be noise.
mod.events:on("game.ready", function()
  local ok, World = pcall(require, "src.world.gen2.World")
  if not (ok and World and World.gen2VoxelWorldDraw) then return end
  local Game = require("src.core.Game")
  local opts = Game and Game.save and Game.save.options
  local stored = type(opts) == "table" and opts.pipelines and opts.pipelines.voxel
  if tonumber(stored) and tonumber(stored) > 0 then
    require("src.render.Pipelines").setLevel("voxel", stored)
  end
end)

-- ------- the free-roam rungs' inputs and their walk
--
-- 1ST and 3RD need two things no other rung does, and each is a named seam.
-- Both rungs are one rig -- the boom behind the shoulder is a number inside
-- it (lib/ThirdPerson.lua) -- so both are installed by the same two calls:
--
-- FirstPerson.install claims the LOOK inputs the engine ignores: the right
-- stick's axes (Game:gamepadaxis passes them to Input, which returns early
-- on anything but the left pair), relative mouse motion (love.mousemoved --
-- there is no Game handler to wrap; the engine's own callback only feeds
-- the mouse-as-touch debug path, which stays untouched), the mouse buttons
-- while the cursor is captured (A and B -- there is no cursor to click UI
-- with), and any touch that lands off the overlay's controls (a drag on
-- open screen is the look; the d-pad and buttons still go to
-- TouchControls, whose own d-pad finger is also read back analog as the
-- move vector). Every wrap forwards whatever it does not claim, and claims
-- only while one of the two rungs is actually driving.
--
-- FreeMove.install wraps OverworldState:handleInput -- the one choke point
-- where the grid walk reads the pad, and the same seam the engine's own
-- Cycling Road pull lives behind. While either drives, the walk is continuous
-- and camera-relative; the player's logical cell stays synced and every
-- per-cell consequence still runs through the engine's own machinery
-- (onStepComplete, checkEdgeExit, checkLedgeHop, checkBoulderPush). The
-- file argues the whole arrangement.
FirstPerson.install()
FreeMove.install()

-- ------- the zooms, and the battle camera the player can steer
--
-- CamControl claims the wheel, Q/E, the mouse and the touch screen for
-- whichever camera is actually in front of the player -- the staged
-- battle's, the third-person boom, or the engine's own survey zoom -- and
-- forwards everything else. Installed AFTER the two above deliberately: a
-- wrap installed later is the OUTER one, so a fight gets first refusal on
-- the mouse and the fingers, which is right, because while one is staged
-- the free-roam look is not driving.
CamControl.install()
V.require("GoldBattle").install()

-- ------- SELECT walks the angle ladder
--
-- The same step the "3" key makes, on the pad's own button: a phone (and
-- a controller) has no number row, and SELECT has no overworld job in
-- Gen 1 -- its work is all in-menu, which this wrap never sees. The seam
-- is OverworldState:handleInput, the same choke point the free walk
-- replaced: every gate above it -- menus, dialogs, scripted moves,
-- transitions -- already decided the overworld owns the buttons, so a
-- SELECT here is free-roam by construction, exactly like the key. When
-- the step is refused (mid-warp, no 3D pass) the press falls through to
-- the engine's own handling, which is a no-op, as ever.
--
-- Installed AFTER FreeMove.install, deliberately: its wrap must sit
-- OUTSIDE the free walk's, or first person -- where FreeMove.tick takes
-- the frame and never calls further in -- would eat the button, and the
-- one rung SELECT could not step off of would be 1ST itself.
do
  local OverworldState = require("src.world.OverworldController")
  if not OverworldState.gen2VoxelSelectHook then
    local inner = OverworldState.handleInput
    function OverworldState:handleInput(...)
      local Game = require("src.core.Game")
      local input = Game.input
      if input and input.wasPressed and input:wasPressed("select") then
        if cycleVoxel(Game) then return end
      end
      return inner(self, ...)
    end
    OverworldState.gen2VoxelSelectHook = true
  end
end

-- ------- the konami code, and everything it turns on
--
-- Installed last of the input seams so its handleInput reasoning sits
-- outside FreeMove's and SELECT's. The detector itself does not live on
-- handleInput at all -- it reads the fixed step's own press queue, which
-- ------- edge-anchored menus stay in the GB frame
--
-- The engine's zoom-aware anchoring (Renderer:setUIAnchor) docks the START
-- menu to the window's top-right edge.
do
  local Game = require("src.core.Game")
  if not Game.gen2VoxelAnchorHold then
    local inner = Game.uiAnchorsHeldInStack
    function Game.uiAnchorsHeldInStack(stack)
      return inner(stack)
    end
    Game.gen2VoxelAnchorHold = true
  end
end

-- ------- and the hour on the flat world
--
-- The clock reaches the diorama through the voxel shader's own tint uniform,
-- which the 2D tile path never runs -- so with the mode off, the same evening
-- that fell on the diorama left the flat world at permanent noon. One clock,
-- two worlds, one of them ignoring it. DayTint paints the same multiply over
-- the composited flat world, between the world blit and the UI blit; the
-- reasoning for that exact instant is in the file.
DayTint.install()

-- ------- what time it is
--
-- The cycle's clock rides the SAVE SLOT (save.modData, via mod.save): what
-- time it is in the game is a fact about that journey, like where the player
-- is standing. Written on the engine's save.writing event -- the moment before
-- the bytes hit disk -- and read back whenever a save is opened or begun. A
-- save with no clock in it starts at day; that is DayNight.restore's
-- fallback, and also the DAYTIME row's own default.
mod.events:on("save.writing", function()
  DayNight.store()
end)

mod.events:on("save.loaded", function()
  DayNight.restore()
  -- a save written before this mod was installed can carry TILT or GBC FX
  -- switched on, and their rows are not there to switch them back off (see
  -- pinEngineFx). Answered here rather than only when the menu opens, so a
  -- player who never opens it is not left playing under one.
  pinEngineFx()
end)

mod.events:on("save.created", function()
  DayNight.restore()
  pinEngineFx()
end)

-- The engine's own time-of-day seam. OverworldState:timeOfDay() is an
-- eternal "DAY" until a mod answers here; answering it hands the period to
-- the map.palette hook (ctx.tod) and music.select, so a palette or music
-- pack keyed to night works with this mod's clock for free. next() first: a
-- mod loaded before this one that already moved the time keeps its answer.
mod.hooks:wrap("world.tod", function(next, tod, ctx)
  local out = next(tod, ctx)
  if out ~= tod then return out end
  return DayNight.worldTod(out, ctx)
end)

mod.exports.version = "1.10.31"
-- Native frame geometry is honored by visible, shadow and ghost billboards.
mod.exports.supportsVariableSpriteGeometry = true
-- exposed so a companion mod can pin its own tiles' shapes or read the
-- camera without reaching into this mod's file layout
mod.exports.lib = V
mod.exports.registerBattleSpriteProvider = V.require("BattleSprites").register
-- Additive companions register their own region's profile without patching us.
local TileShape=V.require('TileShape')
profileExtensions=V.require('ProfileExtensions').new(function()return rawData('voxel_heights')end,TileShape.builtinHeights(),function(profile)
  ChunkMesher.invalidate()
  TileShape.inject(profile)
  V.require('Buildings').inject(profile)
end)
mod.exports.profileExtensions=profileExtensions
