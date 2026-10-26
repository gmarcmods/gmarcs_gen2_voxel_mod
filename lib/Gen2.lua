-- Gold-side surface adapter: the few spots where the mod's Gen 1-facing
-- reads do not line up with the Gen 2 runtime, gathered here so the rest of
-- the pass needs no generation branch of its own.
--
-- The engine already fronts the gen1 names the mod calls (src.world.Map is
-- the gen2 Map under gold, src.core.Game the gen2 Game), and gen2's Map and
-- NPC were built with a mod's vocabulary in mind -- tileAt, the cell
-- predicates, the seven-value pose.  What is left is the shape of the data
-- boxes the engine hands over:
--
--   * the world object: gen1 keeps it at game.overworld, gold at game.world,
--   * neighbour records: gen1 carries a live Map in `.map`, gold only
--     `id / ox / oy` with the def in World.maps / World.tilesets,
--   * the player sprite: gen2's Player is not an NPC, so it has no `pose`
--     -- the mod's cast reads every entity through pose().

local V = ...

local Gen2 = {}

local function gen2State(state)
  return state and state.map and state.map.tileset
         and state.map.tileset.generation == 2
end
Gen2.isGold = gen2State

-- The overworld surface both generations keep on differently-named fields
-- of the driver game object.
function Gen2.world(game)
  return (game and (game.overworld or game.world)) or nil
end

-- Resolve one neighbour record's def into a live Map, once per neighbour
-- list (the engine rebuilds the list when the view size or map changes, so
-- the flag is per list, not per map).  Gold's neighbour records intentionally
-- carry no Map -- the draw path reads defs directly -- so the mod builds
-- them the same way the engine does when it needs a Map from a def
-- (src/world/gen2/World.lua:6988).
local function resolveNeighbors(state)
  local list = state.neighbors
  if not list or list.__gen2maps then return list end
  list.__gen2maps = true
  local maps = state.maps
  local tilesets = state.tilesets
  if not (maps and tilesets) then return list end
  local Map = require("src.world.Map")
  for _, nb in ipairs(list) do
    if not nb.map then
      local def = maps[nb.id]
      local tset = def and tilesets[def.tileset]
      if def and tset then nb.map = Map.new(def, tset) end
    end
  end
  return list
end

-- The mod iterates `state.neighbors` and reads `nb.map` off each record.
-- Returns the list ready for that read either generation.
function Gen2.neighborsOf(state)
  if gen2State(state) then return resolveNeighbors(state) end
  return state.neighbors
end

-- Preserve native NPC poses. Player interfaces vary across engine builds:
-- some expose pose(), others walkPhase()/drawFlip(). Both player paths must
-- use the visible walking cadence, while retaining native facing and lift.
function Gen2.poseFor(e, map, isPlayer)
  if e.pose and not isPlayer then
    return function() return e:pose() end
  end
  return function()
    local sprite, x, y, facing, phase, flip, hopping
    if e.pose then
      sprite, x, y, facing, phase, flip, hopping = e:pose()
    else
      sprite, x, y, facing, hopping = e.sprite, e.px, e.py, e.facing, false
      phase = e:walkPhase()
      flip = e.stepFlip
      if e.drawFlip then flip = e:drawFlip() end
    end
    local walk = e.voxelFreeWalk
    if walk then
      local cycle = walk.distance % 16
      phase = walk.moving and cycle >= 4 and cycle < 12 and 1 or 0
      flip = math.floor(walk.distance / 16) % 2 == 1
    end
    if love and love.timer and love.timer.getTime and V.require then
      phase, flip = V.require('WalkAnimation').pose(e, phase, flip,
        love.timer.getTime(), map)
    end
    return sprite, x, y, facing, phase, flip, hopping
  end
end

-- The ground height lookup in VoxelScene reads map:cellTile to find the
-- tile a cell stands on.  On gold that method returns a COLL_* byte -- a
-- different number space, and the lookup would resolve whatever tile id
-- the byte collides with.  Gold resolves the same question through
-- TileShape.at on the per-tile grid; this hands the mod that answer.
local TILELAGS = { stair_e = true, stair_w = true,
                   stair_down_e = true, stair_down_w = true }

function Gen2.groundHeightAt(map, shapes, cellX, cellY)
  if map.id=='TIN_TOWER_ROOF'and map:inBounds(cellX,cellY)then return 48 end
  local tx, ty = cellX * 2, cellY * 2
  local tile = map:tileAt(tx, ty)
  if tile == nil then return 0 end
  -- A complete authored platform can raise a shared floor tile in just one
  -- room. Its explicit support comes from the finished structure cache,
  -- without forcing or reentering meshing from an actor query.
  local support = V.require("Structures").authoredSupportAt(map, tx, ty)
  if support then return support end
  local s = V.require("TileShape").at(map, shapes, tile, tx, ty)
  if not s or not s.h or s.h <= 0 then return 0 end
  if TILELAGS[s.art] then return 0 end
  return s.h
end

-- <UNIQUE_ANCHOR_ONE>

-- The eight BG palettes the 2D screen is drawing this map with right now
-- (World:bakeMapImage resolves exactly this: `Palettes.bgSet(palettes,
-- map.def, daytime)`, folded through the cave flicker on DARK maps), so
-- the 3D atlas can be recolored through the same slots and match the flat
-- ground shade for shade.  nil when the palette cache has not loaded.
function Gen2.goldBgSet(world, map)
  local Palettes = require("src.world.gen2.Palettes")
  local def = map and map.def
  local picks = world and world.palettes and def
  if not (picks and world.daytime) then return nil end
  local daytime = world.daytime or "DAY"
  local bgSet = Palettes.bgSet(world.palettes, def, daytime)
  if not bgSet then return nil end
  if daytime == "DARK" then
    return Palettes.withCaveFlicker(bgSet, world.flickerPhase or 1)
  end
  return bgSet
end

-- The atlas the 3D pass should texture this gold map's ground with: the
-- sheet recolored per-tile through its bgSet (see TerrainAtlas.forGoldMap).
-- nil for anything that can't be colored this way -- a tileset with no
-- tilePalettes (gen 1), the pre-palette-cache world, a nil bgSet -- so the
-- caller falls back to forMap and samples the plain sheet as before.
function Gen2.goldAtlas(world, map)
  V.require("FlowerAnimation").bind(world)
  V.require("WaterAnimation").bind(world)
  if not (world and map and map.tileset and map.tileset.tilePalettes) then
    return nil
  end
  local bgSet = Gen2.goldBgSet(world, map)
  if not bgSet then return nil end
  return V.require("TerrainAtlas").forGoldMap(map, bgSet)
end

-- The ctx the engine hands a world pipeline on Gen 1
-- (src/world/OverworldController.lua:4827).  Gold's engine never builds
-- one -- its overworld draws flat and Pipelines.drawWorld is never called
-- -- so the mod's World:draw patch (main.lua) builds it here from the gen 2
-- runtime's own numbers: the same dims, zoom and view size World:draw
-- derives to frame its camera.
--
-- The camera follow is mirrored here rather than assumed done: the flat
-- path moves the camera in World:draw itself, and the pipelined path skips
-- the flat draw, so the 3D camera has to be pointed at the player by the
-- hand that renders instead.
function Gen2.healingMachine(world)
  if gen2State(world) then V.require('HealingMachine').draw(world) end
end

function Gen2.worldCtx(world, level, game)
  local w, h = love.graphics.getDimensions()
  local field = require('src.render.Playfield')
  -- pixelScale was added when Game2 returned to LOVE window coordinates.
  -- Older releases already enter this hook in framebuffer coordinates.
  local windowFrame = type(field.pixelScale) == 'function'
  local pixelFrame = game and not windowFrame and game.pixelRatio ~= nil
  local dpi = love.window and love.window.getDPIScale and love.window.getDPIScale() or 1
  dpi = math.max(tonumber(dpi) or 1, 1e-6)
  local presentScale = pixelFrame and 1 or 1 / dpi
  if pixelFrame or windowFrame then w, h = field.dimensions() end
  local s = world:zoomScale()
  if windowFrame then w, h, s = w * dpi, h * dpi, s * dpi end
  local vw = math.ceil(w / s)
  local vh = math.ceil(h / s)
  if vw % 2 ~= 0 then vw = vw + 1 end
  if vh % 2 ~= 0 then vh = vh + 1 end
  local p = world.player
  if p then world.camera:follow(p.px, p.py, vw, vh) end
  if world.shake then
    world.camera.y = world.camera.y + (world.shake.phase or 0)
  end
  local cam = world.camera
  -- Gold's field-FX surface is thinner than Gen 1's -- an emote bubble and
  -- the heal-machine show, no dust/cut/rod/fly -- so drawFx only exposes
  -- the piece that has a gold home.  dt/dust/cut arrive as they get one.
  local function fxEmote(project, scale)
    local emote = world.emote
    local ent = emote and emote.entity
    if not (emote and emote.image and ent) then return end
    local x, y, z = V.require("VoxelScene").entityHeadPoint(world, ent)
    local sx, sy, perspective = project(x, z, y)
    if not sx then return end
    local size = scale * math.max(0.1, math.min(4, perspective or 1))
    local iw, ih = emote.image:getDimensions()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(emote.image, sx - iw * size / 2,
      sy - ih * size - 2 * scale, 0, size, size)
  end
  return {
    state = world,
    cam = cam,
    vw = vw, vh = vh,
    bgY = 0,
    width = w, height = h,
    pixelWidth = (pixelFrame or windowFrame) and w or nil,
    pixelHeight = (pixelFrame or windowFrame) and h or nil,
    presentScale = presentScale,
    scale = s,
    level = level,
    -- gold is CGB-native: its tiles carry their own colour, so no SGB zone
    -- palette is mapped -- the same true-colour mode Gen 1 renders in
    paletteFor = function() return nil end,
    drawFx = function(project, scale)
      V.require("CanvasOrientation").withRawFx(function()
        pcall(fxEmote, project, scale)
      end)
    end,
  }
end

return Gen2
