return function(game)
  local wait = function(n) for _ = 1, n do coroutine.yield() end end
  wait(40)

  local exports = game.mods.exports or {}
  local exp = exports.gmarcs_gen2_voxel_mod or exports.GEN2_VOXEL
  local V = exp and exp.lib
  if not V then print("[editor] voxel mod library unavailable"); return end

  local GbcPalette = require("src.render.GbcPalette")
  game.save.options.color = "gbc"
  GbcPalette.setMode("gbc")

  local Pipelines = require("src.render.Pipelines")
  Pipelines.setLevel("voxel", 1)
  Pipelines.setLevel("tiltshift", 0)
  Pipelines.syncOptions(game.save.options)

  V.require("DayNight").setting:setIndex(2, game)

  local Tools = dofile(V.mod.path .. "/tools/EditorUI.lua")
  local Model = dofile(V.mod.path .. "/tools/EditorModel.lua")
  local TileShape = V.require("TileShape")
  local Buildings = V.require("Buildings")
  local ChunkMesher = V.require("ChunkMesher")
  local GameViewport = require("src.render.GameViewport")
  local Voxel3D = V.require("Voxel3D")
  local Assets = require("src.render.Assets")
  local Gen2 = V.require("Gen2")
  local TerrainAtlas = V.require("TerrainAtlas")
  local Palettes = require("src.world.gen2.Palettes")

  local ZoneColors = dofile(V.mod.path .. "/tools/ZoneColors.lua")
  local ZoneResolve = dofile(V.mod.path .. "/tools/ZoneResolve.lua")(TileShape)
  local ZoneOverlay = dofile(V.mod.path .. "/tools/ZoneOverlay.lua")(TileShape, ZoneColors, ZoneResolve)
  local ModManager = dofile(V.mod.path .. "/tools/ModManager.lua")
  local Session = dofile(V.mod.path .. "/tools/EditorSession.lua")(Model, ModManager)
  local FolderPicker = dofile(V.mod.path .. "/tools/FolderPicker.lua")
  local furniture = {Dialog=dofile(V.mod.path .. "/tools/VoxelAssetEditor.lua"),
    selection=dofile(V.mod.path .. "/tools/ObjectSelection.lua").new()}
  furniture.ClassEditor = dofile(V.mod.path .. "/tools/ClassEditor.lua")
  furniture.overlay = dofile(V.mod.path .. '/tools/AssetOverlay.lua')
  local AutoScanner = dofile(V.mod.path .. "/tools/AutoScanner.lua")

  local ui = Tools.new()
  local w = game.world

  -- Discover workspace and mods
  local workspacePath = ModManager.resolveWorkspace(V.mod.path)
  local currentModInfo = ModManager.getCurrentMod(V)

  -- Auto-scan tilesets
  local scanResult = AutoScanner.scanTilesets(w)

  local profile = nil
  do
    local ok, p = pcall(V.data, "voxel_heights")
    if ok and p then profile = p end
  end
  -- If profile is empty or missing, suggest one from the scan
  if not profile or not profile.tilesets or next(profile.tilesets) == nil then
    profile = AutoScanner.suggestProfile(scanResult, profile)
  end
  -- Reopen the last project automatically when it is still present and its
  -- profile is readable.  A stale preference must never prevent the editor
  -- from booting into the bundled source project.
  local initialPath = ModManager.absolutePath(V.mod.path)
  local initialLabel = currentModInfo and currentModInfo.id
  local lastPath = ModManager.loadLastProject and ModManager.loadLastProject()
  if lastPath then
    local lastAbsolute = ModManager.absolutePath(lastPath)
    local lastProfile = lastAbsolute and ModManager.loadProfile(lastAbsolute)
    if lastProfile then
      initialPath = lastAbsolute
      initialLabel = lastAbsolute:match("([^/]+)$") or initialLabel
      profile = lastProfile
    end
  end
  local session = Session.new(initialPath, profile, initialLabel)
  if ModManager.saveLastProject then ModManager.saveLastProject(session.path) end
  local model = session.model

  -- Per-map override state
  local overrideRegistry = ModManager.loadOverrideRegistry(session.path)
  local currentOverridePath = nil

  local function injectLive(preview)
    furniture.assetEntries=nil
    local mapId = w.map and w.map.id
    local override = mapId and ModManager.loadMapOverride(session.path, overrideRegistry, mapId)
    local spec = preview or (model.snapshot and model:snapshot() or model:fuse())
    if override then spec = model:deepcopy(spec) end
    if override then model:applyMapOverride(spec, override) end
    ChunkMesher.invalidate()
    TileShape.inject(spec)
    Buildings.inject(spec)
  end

  local function S() return love.graphics.getWidth(), love.graphics.getHeight() end

  local tilesetIds, tilesetDefs, tilesetOwned = {}, {}, {}
  for mapId, def in pairs(w.maps or {}) do
    if type(def) == "table" and type(def.tileset) == "string"
       and not tilesetDefs[def.tileset] then
      local tsDef = w.tilesets and w.tilesets[def.tileset]
      if tsDef then
        tilesetIds[#tilesetIds + 1] = def.tileset
        tilesetDefs[def.tileset] = tsDef
      end
    end
  end
  table.sort(tilesetIds)
  for _, id in ipairs(tilesetIds) do
    tilesetOwned[id] = profile and profile.tilesets and profile.tilesets[id] ~= nil
  end

  local mapsByTset = {}
  for mapId, def in pairs(w.maps or {}) do
    if type(def) == "table" and type(def.tileset) == "string" then
      local b = mapsByTset[def.tileset]
      if not b then b = {}; mapsByTset[def.tileset] = b end
      b[#b + 1] = mapId
    end
  end
  for _, b in pairs(mapsByTset) do table.sort(b) end

  local tsetIdx = 1
  local mapIdx = 1
  -- Every panel must refer to the map already shown in the 3D preview.
  for i,id in ipairs(tilesetIds) do
    if w.map and w.map.tileset and id==w.map.tileset.id then tsetIdx=i end
  end
  for i,id in ipairs(mapsByTset[tilesetIds[tsetIdx]] or {}) do
    if w.map and id==w.map.id then mapIdx=i end
  end
  local selectedClass = "wall"

  local statusMsg, statusTime = nil, 0
  furniture.previewActive=false
  local function status(text) statusMsg = text; statusTime = 3.0 end
  local function closeModal()
    if furniture.previewActive then furniture.previewActive=false; injectLive() end
    furniture.previewRevision=nil
    ui._modal, ui._textInputState, ui._createModState = nil, nil, nil
    ui._classEditor, ui._furnitureEditor = nil, nil
    ui._dialogError = nil
    love.keyboard.setTextInput(false)
  end
  local function saved()
    local ok, err = session:save()
    if ok then
      status("Saved " .. session.path)
    else
      status("SAVE FAILED: " .. tostring(err))
      ui._dialogError = tostring(err)
      ui._modal = ui._modal or "error"
    end
    return ok
  end
  local function activated()
    model = session.model
    profile = model.profile
    selectedClass = "wall"
    furniture.index = nil
    furniture.selection:clear()
    currentModInfo = {id=session.label, path=session.path}
    if ModManager.saveLastProject then ModManager.saveLastProject(session.path) end
    overrideRegistry = ModManager.loadOverrideRegistry(session.path)
    for _, id in ipairs(tilesetIds) do
      tilesetOwned[id] = profile.tilesets and profile.tilesets[id] ~= nil
    end
    workspacePath = ModManager.resolveWorkspace(session.path)
    injectLive()
    status("Opened " .. session.path)
  end
  local pendingAction
  local function requestAction(action)
    if session:isDirty() then
      pendingAction = action
      ui._modal = "unsaved"
    else
      action()
    end
  end
  local pendingNative
  local clickX, clickY, clickBtn = nil, nil, nil
  local hoveredTile = nil
  local hoveredInfo = nil

  local activeTool = "select"
  local mouseDown = false

  local function curTsetId() return tilesetIds[tsetIdx] end
  local function curMapId()
    local tm = mapsByTset[curTsetId()]
    return tm and tm[mapIdx]
  end

  local q1x, q1y, q1w, q1h = 0, 0, 100, 100
  local pendingMap = nil

  local camActive = false
  local camInit = false
  local camX, camZ = 0, 0
  local camH = 8
  local camAz = 180
  local camEl = 35
  local camDist = 96
  local camFOV = 50 * math.pi / 180
  local camDX, camDY = 0, 0

  local function recalcLayout()
    local W, H = S()
    local SIDEBAR_W = 180
    local GAP = 4
    local gridX = SIDEBAR_W + GAP
    local gridW = W - SIDEBAR_W - GAP
    local gridH = H
    local halfGW = math.floor(gridW / 2)
    local halfGH = math.floor(gridH / 2)
    q1x = gridX
    q1y = 0
    q1w = halfGW - math.floor(GAP / 2)
    q1h = halfGH - math.floor(GAP / 2)
  end

  local innerDraw = love.draw
  love.draw = function()
    ui:beginFrame()
    -- Modal events belong only to the dialog, never the map behind it.
    local modalEvents
    if ui._modal then
      modalEvents = {ui.clicked, ui.rightClicked, ui.scrollDy}
      ui.clicked, ui.rightClicked, ui.scrollDy = false, false, 0
      clickX, clickY, mouseDown = nil, nil, false
    end
    hoveredInfo = nil
    hoveredTile = nil

    if camActive then
      local DEG = math.pi / 180
      local azr = camAz * DEG
      local elr = camEl * DEG
      local focus = { camX, camH, camZ }
      local horiz = camDist * math.cos(elr)
      Voxel3D.camera = {
        eye = {
          focus[1] - horiz * math.sin(azr),
          focus[2] + camDist * math.sin(elr),
          focus[3] - horiz * math.cos(azr),
        },
        focus = focus,
        fov = camFOV,
        up = { 0, 1, 0 },
      }
    end

    local origBegin = GameViewport.begin
    local origFinish = GameViewport.finish
    GameViewport.begin = function(generation)
      local rect = origBegin(generation)
      if not GameViewport.canvas then
        local w, h = love.graphics.getDimensions()
        GameViewport.canvas = love.graphics.newCanvas(w, h)
        GameViewport.canvas:setFilter("nearest", "nearest")
        GameViewport.frameActive = true
        GameViewport.rect = { x = 0, y = 0, width = w, height = h }
        GameViewport.full = { width = w, height = h, dpiX = 1, dpiY = 1 }
      end
      return rect
    end
    GameViewport.finish = function()
      love.graphics.setCanvas()
    end
    if innerDraw then
      local ok,err=pcall(innerDraw)
      furniture.renderError=not ok and tostring(err) or nil
    end
    GameViewport.begin = origBegin
    GameViewport.finish = origFinish

    local G2 = love.graphics
    local W, H = S()
    recalcLayout()

    local SIDEBAR_W = 180
    local GAP = 4
    local gridX = SIDEBAR_W + GAP
    local gridW = W - SIDEBAR_W - GAP
    local gridH = H
    local halfGW = math.floor(gridW / 2)
    local halfGH = math.floor(gridH / 2)

    local q2x = q1x + q1w + GAP
    local q2y = 0
    local q2w = gridW - q1w - GAP
    local q2h = halfGH - math.floor(GAP / 2)
    local q3x = gridX
    local q3y = halfGH + math.ceil(GAP / 2)
    local q3w = q1w
    local q3h = gridH - halfGH - math.ceil(GAP / 2)
    local q4x = q2x
    local q4y = q3y
    local q4w = q2w
    local q4h = q3h

    local BORDER_W = 3

    local function quadPanel(px, py, pw, ph, title, titleColor)
      titleColor = titleColor or {0.5, 0.65, 1.0}
      G2.setColor(0.06, 0.06, 0.08, 0.78)
      G2.rectangle("fill", px, py, pw, ph)
      G2.setLineWidth(BORDER_W)
      G2.setColor(0.35, 0.40, 0.55)
      G2.rectangle("line", px, py, pw, ph)
      G2.setLineWidth(1)
      if title then
        local tw = G2.getFont():getWidth(title) + 12
        G2.setColor(0.12, 0.14, 0.20, 0.92)
        G2.rectangle("fill", px, py, tw, 20)
        G2.setLineWidth(1)
        G2.setColor(titleColor[1], titleColor[2], titleColor[3], 0.9)
        G2.rectangle("line", px, py + 20, tw, 1)
        G2.setColor(titleColor[1], titleColor[2], titleColor[3])
        G2.print(title, px + 6, py + 3)
      end
    end

    G2.setColor(0.06, 0.06, 0.08, 0.88)
    G2.rectangle("fill", 0, 0, SIDEBAR_W, H)
    G2.setLineWidth(BORDER_W)
    G2.setColor(0.35, 0.40, 0.55)
    G2.rectangle("line", SIDEBAR_W - 2, 0, 2, H)
    G2.setLineWidth(1)

    quadPanel(q1x, q1y, q1w, q1h, "3D VIEW", {0.4, 0.8, 0.5})
    local vpCanvas = GameViewport.canvas
    if vpCanvas then
      local cw, ch = vpCanvas:getWidth(), vpCanvas:getHeight()
      local scale = math.min(q1w / cw, q1h / ch)
      local dw, dh = cw * scale, ch * scale
      local dx = q1x + math.floor((q1w - dw) / 2)
      local dy = q1y + 20 + math.floor((q1h - 20 - dh) / 2)
      G2.setColor(1, 1, 1, 1)
      G2.setScissor(q1x, q1y + 20, q1w, q1h - 20)
      G2.draw(vpCanvas, dx, dy, 0, scale, scale)
      G2.setScissor()
    end
    if furniture.renderError then
      G2.setColor(1,.4,.3)
      G2.printf('3D render error: '..furniture.renderError,q1x+8,q1y+30,q1w-16)
    end
    if w.map and (not furniture.assetEntries or furniture.assetMap~=w.map.id) then
      furniture.assetEntries=furniture.overlay.entries(model:snapshot(),w.map)
      furniture.assetMap=w.map.id
    end

    local sx = 4
    local sy = 4
    local sw = SIDEBAR_W - 8

    G2.setColor(0.5, 0.65, 1.0)
    G2.print("VOXEL EDITOR", sx, sy)
    sy = sy + 20

    -- Mod management section
    G2.setColor(0.4, 0.8, 0.5)
    G2.print("MOD", sx, sy)
    sy = sy + 14

    local modBtnW = math.floor((sw - 2) / 3)
    local modBtnY = sy
    local modBtnH = 18

    -- NEW button
    if ui:button("NEW", sx, modBtnY, modBtnW, modBtnH, {centered = true}) then
      pendingNative = "new"
    end

    -- LOAD button
    if ui:button("LOAD", sx + modBtnW + 2, modBtnY, modBtnW, modBtnH, {centered = true}) then
      pendingNative = "open"
    end

    -- SAVE button
    if ui:button("SAVE", sx + 2 * (modBtnW + 2), modBtnY, modBtnW, modBtnH, {centered = true}) then
      saved()
    end

    sy = modBtnY + modBtnH + 4

    if ui:button("SAVE AS", sx, sy, 82, modBtnH, {centered=true}) then
      pendingNative = "save_as"
    end
    if ui:button("DELETE", sx+86, sy, 82, modBtnH, {centered=true}) then
      ui._modal, ui._dialogError = "delete", nil
    end
    sy = sy + modBtnH + 4

    -- Current mod info
    if currentModInfo then
      G2.setColor(0.6, 0.65, 0.7)
      G2.print(session.label .. (session:isDirty() and " *" or ""), sx, sy)
    end
    sy = sy + 14

    if not furniture.lightPreview then
      furniture.lightPreview=dofile(V.mod.path..'/tools/EditorLight.lua').new(w,Palettes,function() injectLive() end)
    end
    if furniture.lightPreview:available() then
      if ui:button(w.flashUsed and 'LIGHT: ON (FLASH)' or 'LIGHT: OFF',sx,sy,sw,20,{centered=true}) then furniture.lightPreview:toggle() end
      sy=sy+24
    end

    -- Scan summary
    local scanSummary = AutoScanner.summary(profile, scanResult)
    G2.setColor(0.45, 0.5, 0.55)
    G2.print(scanSummary, sx, sy)
    sy = sy + 14

    G2.setColor(0.35, 0.40, 0.55)
    G2.line(sx, sy, sx + sw, sy)
    sy = sy + 4

    local toolY = sy
    local toolH = 20
    local toolW = math.floor((sw - 2) / 2)
    local selectHov = ui.mx >= sx and ui.mx <= sx + toolW and ui.my >= toolY and ui.my <= toolY + toolH
    local paintHov = ui.mx >= sx + toolW + 2 and ui.mx <= sx + sw and ui.my >= toolY and ui.my <= toolY + toolH

    if activeTool == "select" then
      G2.setColor(0.30, 0.55, 0.85, 0.95)
    elseif selectHov then
      G2.setColor(0.22, 0.35, 0.55, 0.9)
    else
      G2.setColor(0.14, 0.16, 0.22, 0.9)
    end
    G2.rectangle("fill", sx, toolY, toolW, toolH)
    G2.setColor(0.35, 0.40, 0.55)
    G2.rectangle("line", sx, toolY, toolW, toolH)
    G2.setColor(activeTool == "select" and {1,1,1} or {0.7, 0.75, 0.8})
    local selLabel = "[1] SELECT"
    G2.print(selLabel, sx + (toolW - G2.getFont():getWidth(selLabel)) / 2, toolY + 3)

    if activeTool == "paint" then
      G2.setColor(0.85, 0.45, 0.25, 0.95)
    elseif paintHov then
      G2.setColor(0.55, 0.30, 0.18, 0.9)
    else
      G2.setColor(0.14, 0.16, 0.22, 0.9)
    end
    G2.rectangle("fill", sx + toolW + 2, toolY, toolW, toolH)
    G2.setColor(0.35, 0.40, 0.55)
    G2.rectangle("line", sx + toolW + 2, toolY, toolW, toolH)
    G2.setColor(activeTool == "paint" and {1,1,1} or {0.7, 0.75, 0.8})
    local paintLabel = "[2] PAINT"
    G2.print(paintLabel, sx + toolW + 2 + (toolW - G2.getFont():getWidth(paintLabel)) / 2, toolY + 3)

    if selectHov and clickBtn == 1 and clickX then activeTool = "select" end
    if paintHov and clickBtn == 1 and clickX then activeTool = "paint" end

    sy = sy + toolH + 8

    G2.setColor(0.5, 0.65, 1.0)
    G2.print("TILESETS", sx, sy)
    sy = sy + 14

    local tsetListH = math.floor(H * 0.28)
    local tsetScrollContentH = #tilesetIds * 16
    local tsetScrollY = ui:scrollArea(sx - 2, sy, sw + 4, tsetListH, tsetScrollContentH, "tilesets")
    for i, id in ipairs(tilesetIds) do
      local ry = sy + (i - 1) * 16 - tsetScrollY
      if ry + 16 > sy and ry < sy + tsetListH then
        local sel = (i == tsetIdx)
        local hov = ui.mx >= sx - 2 and ui.mx <= sx - 2 + sw + 4 and
                    ui.my >= ry and ui.my <= ry + 16
        if sel then
          G2.setColor(0.25, 0.40, 0.65)
          G2.rectangle("fill", sx - 2, ry, sw + 4, 16)
        elseif hov then
          G2.setColor(0.22, 0.22, 0.28, 0.6)
          G2.rectangle("fill", sx - 2, ry, sw + 4, 16)
        end
        local mark = tilesetOwned[id] and "* " or "  "
        G2.setColor(sel and {1,1,1} or {0.8,0.8,0.85})
        G2.print(mark .. id, sx, ry + 1)
        if hov and clickBtn == 1 and clickX and clickY then
          tsetIdx = i; mapIdx = 1
          pendingMap = curMapId()
        end
      end
    end
    ui:scrollEnd()

    sy = sy + tsetListH + 6
    G2.setColor(0.5, 0.65, 1.0)
    G2.print("MAPS", sx, sy)
    sy = sy + 14

    local tsetMaps = mapsByTset[curTsetId()] or {}
    local mapListH = H - sy - 50
    local mapScrollContentH = #tsetMaps * 16
    local mapScrollY = ui:scrollArea(sx - 2, sy, sw + 4, mapListH, mapScrollContentH, "maps")
    for i, id in ipairs(tsetMaps) do
      local ry = sy + (i - 1) * 16 - mapScrollY
      if ry + 16 > sy and ry < sy + mapListH then
        local sel = (i == mapIdx)
        local hov = ui.mx >= sx - 2 and ui.mx <= sx - 2 + sw + 4 and
                    ui.my >= ry and ui.my <= ry + 16
        if sel then
          G2.setColor(0.25, 0.40, 0.65)
          G2.rectangle("fill", sx - 2, ry, sw + 4, 16)
        elseif hov then
          G2.setColor(0.22, 0.22, 0.28, 0.6)
          G2.rectangle("fill", sx - 2, ry, sw + 4, 16)
        end
        G2.setColor(sel and {1,1,1} or {0.8,0.8,0.85})
        G2.print("  " .. id, sx, ry + 1)
        if hov and clickBtn == 1 and clickX and clickY then
          if i ~= mapIdx then
            mapIdx = i
            pendingMap = id
          end
        end
      end
    end
    ui:scrollEnd()

    do
      local mapId = curMapId()
      if mapId and w.imageFor then
        local ok, img = pcall(w.imageFor, w, mapId)
        if ok and img then
          local iw, ih = img:getWidth(), img:getHeight()
          if iw > 0 and ih > 0 then
            local aw, ah = q2w, q2h
            local s = math.min((aw - 12) / iw, (ah - 30) / ih)
            local dw2, dh2 = iw * s, ih * s
            local dx2 = q2x + 6 + math.floor((aw - 12 - dw2) / 2)
            local dy2 = q2y + 24 + math.floor((ah - 30 - dh2) / 2)
            quadPanel(q2x, q2y, q2w, q2h, "MAP", {0.5, 0.65, 1.0})
            local mapW, mapH = math.floor(iw / 8), math.floor(ih / 8)
            G2.setColor(1, 1, 1, 1)
            G2.setScissor(q2x + 2, q2y + 20, q2w - 4, q2h - 22)
            G2.draw(img, dx2, dy2, 0, s, s)
            if w.map then
              local okShapes, shapes = pcall(TileShape.forMap, w.map)
              if okShapes and shapes then
                local spec = model:snapshot()
                pcall(ZoneOverlay.drawMap, spec, w.map, shapes, dx2, dy2, s, mapW, mapH)
              end
            end
            furniture.overlay.draw(furniture.assetEntries or {},'map',dx2,dy2,s)
            if activeTool == "select" and w.map and w.map.id==mapId and not ui._modal then
              local cell=8*s
              local tx,ty=math.floor((ui.mx-dx2)/cell),math.floor((ui.my-dy2)/cell)
              if tx>=0 and ty>=0 and tx<mapW and ty<mapH then
                if ui.clicked then furniture.selection:begin(w.map,tx,ty)
                elseif ui.mouseDown then furniture.selection:extend(w.map,tx,ty) end
              end
              local rx,ry,rw,rh=furniture.selection:bounds(w.map)
              if rx and furniture.selection.source=='map' then
                G2.setColor(1,0.7,0.1,0.25)
                G2.rectangle("fill",dx2+rx*cell,dy2+ry*cell,rw*cell,rh*cell)
                G2.setColor(1,0.8,0.2,1)
                G2.rectangle("line",dx2+rx*cell,dy2+ry*cell,rw*cell,rh*cell)
              end
              local ids=furniture.selection:ids(w.map)
              for y=0,mapH-1 do for x=0,mapW-1 do
                if ids[w.map:tileAt(x,y)] then
                  G2.setColor(0.2,0.85,1,0.20)
                  G2.rectangle('fill',dx2+x*cell,dy2+y*cell,cell,cell)
                  G2.setColor(0.2,0.85,1,0.85)
                  G2.rectangle('line',dx2+x*cell,dy2+y*cell,cell,cell)
                end
              end end
            end
            if activeTool == "paint" and mouseDown and clickBtn == 1 and w.map then
              local mx = (ui.mx) - dx2
              local my = (ui.my) - dy2
              if mx >= 0 and my >= 0 then
                local cellPx = 8 * s
                local mtx = math.floor(mx / cellPx)
                local mty = math.floor(my / cellPx)
                if mtx >= 0 and mtx < mapW and mty >= 0 and mty < mapH then
                  local okTile, tile = pcall(w.map.tileAt, w.map, mtx, mty)
                  if okTile and tile then
                    local tsetId = curTsetId()
                    model:push({op = "set_class", tset = tsetId, class = selectedClass, tile = tile})
                    injectLive()
                  end
                end
              end
            end
            if activeTool == "paint" and clickBtn == 2 and w.map then
              local mx = (ui.mx) - dx2
              local my = (ui.my) - dy2
              if mx >= 0 and my >= 0 then
                local cellPx = 8 * s
                local mtx = math.floor(mx / cellPx)
                local mty = math.floor(my / cellPx)
                if mtx >= 0 and mtx < mapW and mty >= 0 and mty < mapH then
                  local okTile, tile = pcall(w.map.tileAt, w.map, mtx, mty)
                  if okTile and tile then
                    local tsetId = curTsetId()
                    local spec = model:snapshot()
                    local ts = spec.tilesets and spec.tilesets[tsetId]
                    if ts then
                      for cls, group in pairs(ts) do
                        if type(group) == "table" then
                          for _, t in ipairs(group) do
                            if t == tile then
                              model:push({op = "unpin", tset = tsetId, class = cls, tile = tile})
                              injectLive()
                              status("removed " .. tile .. " from " .. cls)
                              break
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
            if ui.mx >= dx2 and ui.mx < dx2 + dw2 and
               ui.my >= dy2 and ui.my < dy2 + dh2 then
              local cellPx = 8 * s
              local hmx = math.floor((ui.mx - dx2) / cellPx)
              local hmy = math.floor((ui.my - dy2) / cellPx)
              if hmx >= 0 and hmx < mapW and hmy >= 0 and hmy < mapH then
                local okShapes2, shapes2 = pcall(TileShape.forMap, w.map)
                if okShapes2 and shapes2 then
                  local okTile2, tile2 = pcall(w.map.tileAt, w.map, hmx, hmy)
                  if okTile2 and tile2 then
                    hoveredInfo = ZoneResolve.at(w.map, shapes2, tile2, hmx, hmy)
                    hoveredInfo.tileId = tile2
                    hoveredInfo.tx = hmx
                    hoveredInfo.ty = hmy
                  end
                end
              end
            end
            G2.setScissor()
          end
        end
      end
    end

    quadPanel(q3x, q3y, q3w, q3h, "TILESET", {0.8, 0.6, 0.3})
    do
      local mapObj = w.map
      local tset = mapObj and mapObj.tileset
      local img = nil
      if tset and tset.image and tset.tilePalettes and w.mapScenes then
        local hour = w.hour and w:hour() or tonumber(os.date("%H")) or 12
        local daytime = Palettes.daytimeFor(mapObj.def, hour, w.flashUsed) or "DAY"
        local bgSet = w.palettes and Palettes.bgSet(w.palettes, mapObj.def, daytime)
        if bgSet then
          local ok, colored = pcall(TerrainAtlas.forGoldMap, mapObj, bgSet)
          if ok then img = colored end
        end
      end
      if not img and tset and tset.image then
        local ok, raw = pcall(Assets.image, tset.image)
        if ok then img = raw end
      end
      furniture.atlas = img
      if img then
        local iw, ih = img:getWidth(), img:getHeight()
        if iw > 0 and ih > 0 then
          local aw, ah = q3w, q3h
          local s = math.min((aw - 12) / iw, (ah - 30) / ih)
          local dw2, dh2 = iw * s, ih * s
          local dx2 = q3x + 6 + math.floor((aw - 12 - dw2) / 2)
          local dy2 = q3y + 24 + math.floor((ah - 30 - dh2) / 2)
          G2.setColor(1, 1, 1, 1)
          G2.setScissor(q3x + 2, q3y + 20, q3w - 4, q3h - 22)
          G2.draw(img, dx2, dy2, 0, s, s)
          local tilesW, tilesH = math.floor(iw / 8), math.floor(ih / 8)
          if activeTool=='select' and w.map and not ui._modal then
            local cell=8*s
            local tx,ty=math.floor((ui.mx-dx2)/cell),math.floor((ui.my-dy2)/cell)
            if tx>=0 and ty>=0 and tx<tilesW and ty<tilesH then
              if ui.clicked then furniture.selection:beginAtlas(w.map,tilesW,tx,ty)
              elseif ui.mouseDown then furniture.selection:extendAtlas(w.map,tilesW,tx,ty) end
            end
            local ids=furniture.selection:ids(w.map)
            for tile in pairs(ids) do
              local x,y=tile%tilesW,math.floor(tile/tilesW)
              G2.setColor(0.2,0.85,1,0.24)
              G2.rectangle('fill',dx2+x*cell,dy2+y*cell,cell,cell)
              G2.setColor(0.2,0.85,1,1)
              G2.rectangle('line',dx2+x*cell,dy2+y*cell,cell,cell)
            end
          end
          local shapes, spec, tsetId
          if w.map then
            local okShapes
            okShapes, shapes = pcall(TileShape.forMap, w.map)
            if okShapes and shapes then
              spec = model:snapshot()
              tsetId = curTsetId()
              pcall(ZoneOverlay.drawTileset, spec, tsetId, shapes, dx2, dy2, s, tilesW, tilesH)
            end
          end
          furniture.overlay.draw(furniture.assetEntries or {},'atlas',dx2,dy2,s,tilesW)
          if activeTool == "paint" and mouseDown and clickBtn == 1 then
            local mx = (ui.mx) - dx2
            local my = (ui.my) - dy2
            if mx >= 0 and my >= 0 then
              local cellPx = 8 * s
              local tx = math.floor(mx / cellPx)
              local ty = math.floor(my / cellPx)
              if tx >= 0 and tx < tilesW and ty >= 0 and ty < tilesH then
                local tileId = ty * tilesW + tx
                local tsetId2 = curTsetId()
                model:push({op = "set_class", tset = tsetId2, class = selectedClass, tile = tileId})
                injectLive()
                status("paint tile " .. tileId .. " = " .. selectedClass)
              end
            end
          end
          if activeTool == "paint" and clickBtn == 2 then
            local mx = (ui.mx) - dx2
            local my = (ui.my) - dy2
            if mx >= 0 and my >= 0 then
              local cellPx = 8 * s
              local tx = math.floor(mx / cellPx)
              local ty = math.floor(my / cellPx)
              if tx >= 0 and tx < tilesW and ty >= 0 and ty < tilesH then
                local tileId = ty * tilesW + tx
                local tsetId2 = curTsetId()
                local spec2 = model:snapshot()
                local ts = spec2.tilesets and spec2.tilesets[tsetId2]
                if ts then
                  for cls, group in pairs(ts) do
                    if type(group) == "table" then
                      for _, t in ipairs(group) do
                        if t == tileId then
                          model:push({op = "unpin", tset = tsetId2, class = cls, tile = tileId})
                          injectLive()
                          status("removed tile " .. tileId .. " from " .. cls)
                          break
                        end
                      end
                    end
                  end
                end
              end
            end
          end
          if ui.mx >= dx2 and ui.mx < dx2 + dw2 and
             ui.my >= dy2 and ui.my < dy2 + dh2 then
            local cellPx = 8 * s
            local htx = math.floor((ui.mx - dx2) / cellPx)
            local hty = math.floor((ui.my - dy2) / cellPx)
            if htx >= 0 and htx < tilesW and hty >= 0 and hty < tilesH then
              local tileId = hty * tilesW + htx
              hoveredTile = tileId
              if shapes then
                local cls = ZoneResolve.forTileType(shapes, tileId)
                local pinned = ZoneResolve.isPinned(spec, tsetId, tileId)
                hoveredInfo = {
                  class = cls, source = pinned and "painted" or "auto",
                  isPainted = pinned,
                  tileId = tileId, tx = htx, ty = hty, tsetId = tsetId,
                  art = shapes[tileId] and shapes[tileId].art or "?",
                  height = shapes[tileId] and shapes[tileId].h or "?",
                }
              end
            end
          end
          G2.setScissor()
        end
      end
    end

    quadPanel(q4x, q4y, q4w, q4h, "TOOLS", {0.85, 0.55, 0.35})
    do
      local px = q4x + 6
      local py = q4y + 24
      local pw = q4w - 12

      if ui:button("NEW CLASS", px, py, 95, 20) then
        ui._classEditor = furniture.ClassEditor.new(model, selectedClass, TileShape.heights())
        ui._modal = "class"
        ui.clicked = false -- The opening click must not blur the new name field.
      end
      local custom = model:snapshot().classes
      if custom and custom[selectedClass] and ui:button("EDIT CLASS", px+101, py, 95, 20) then
        ui._classEditor = furniture.ClassEditor.new(model, selectedClass, TileShape.heights(), true)
        ui._modal = "class"
        ui.clicked = false -- The opening click must not blur the new name field.
      end
      if custom and custom[selectedClass] and ui:button('DELETE CLASS',px+202,py,105,20) then
        ui._classEditor=furniture.ClassEditor.new(model,selectedClass,TileShape.heights(),true)
        ui._classEditor.deleting=true
        ui._classEditor.name.focused=false
        ui._modal='class';ui.clicked=false
      end
      py = py + 26

      if ui:button("NEW VOXEL ASSET",px,py,125,20) then
        local tiles=w.map and furniture.selection:tiles(w.map)
        if tiles then
          ui._furnitureEditor=furniture.Dialog.new(model,curTsetId(),tiles)
          ui._furnitureEditor.atlas = furniture.atlas
          ui._modal="furniture"; ui.clicked=false
        else status("Select tiles in the map or tileset first") end
      end
      local objects=model:snapshot().buildings or {}
      local list={}
      for _,asset in ipairs(objects[curTsetId()] or {}) do
        if type(asset)=="table" and (type(asset.tileShapes)=="table" or type(asset.surfaces)=="table") then list[#list+1]=asset end
      end
      local selectedAsset=w.map and furniture.selection:asset(w.map,list)
      if selectedAsset then
        if ui:button("EDIT ASSET",px+131,py,105,20) then
          local object=selectedAsset
          ui._furnitureEditor=furniture.Dialog.new(model,curTsetId(),object.tiles,object)
          ui._furnitureEditor.atlas = furniture.atlas
          ui._modal="furniture"; ui.clicked=false
        end
        if ui:button('DELETE ASSET',px+242,py,108,20) then
          model:push({op='building_delete',tset=curTsetId(),id=selectedAsset.id})
          injectLive()
          status('Deleted asset: '..selectedAsset.id..' — Undo restores it; Save keeps the change')
          ui.clicked=false
        end
        G2.setColor(.8,.85,.92)
        G2.print('Asset: '..tostring(selectedAsset.id),px,py+26)
        py=py+24
      else
        G2.setColor(.65,.7,.78)
        G2.print('No saved asset selected',px,py+26)
        py=py+24
      end
      py=py+26
      G2.setColor(0.7,0.7,0.75)
      G2.print("Scope: matching tiles in this tileset",px,py)
      py=py+18

      G2.setColor(0.5, 0.65, 1.0)
      G2.print("TOOL: " .. activeTool:upper(), px, py)
      py = py + 16

      if activeTool == "paint" then
        G2.setColor(0.85, 0.55, 0.35)
        G2.print("click/drag to paint", px, py)
        py = py + 13
        G2.setColor(0.7, 0.7, 0.75)
        G2.print("class: " .. selectedClass, px, py)
        py = py + 14
      end

      G2.setColor(0.35, 0.40, 0.55)
      G2.line(px, py, px + pw, py)
      py = py + 6

      if hoveredInfo then
        G2.setColor(0.5, 0.65, 1.0)
        G2.print("INSPECT", px, py)
        py = py + 14
        G2.setColor(0.88, 0.88, 0.88)
        G2.print("tile: " .. tostring(hoveredInfo.tileId), px, py); py = py + 13
        G2.print("class: " .. tostring(hoveredInfo.class), px, py); py = py + 13
        G2.print("source: " .. tostring(hoveredInfo.source), px, py); py = py + 13
        G2.print("height: " .. tostring(hoveredInfo.height), px, py); py = py + 13
        G2.print("art: " .. tostring(hoveredInfo.art), px, py); py = py + 13
        py = py + 6
        G2.setColor(0.35, 0.40, 0.55)
        G2.line(px, py, px + pw, py)
        py = py + 6
      else
        G2.setColor(0.52, 0.52, 0.56)
        G2.print("hover a tile to inspect", px, py)
        py = py + 14
        G2.setColor(0.35, 0.40, 0.55)
        G2.line(px, py, px + pw, py)
        py = py + 6
      end

      local paletteY = py
      local paletteH = q4h - (py - q4y) - 24

      local pinnedClasses = {}
      local spec2 = model:snapshot()
      local tsetId2 = curTsetId()
      if spec2.tilesets and spec2.tilesets[tsetId2] then
        for cls, tiles in pairs(spec2.tilesets[tsetId2]) do
          if type(tiles) == "table" and #tiles > 0 then
            pinnedClasses[cls] = true
          end
        end
      end

      local clickedClass = ui:classList(
        Model.allClasses(model:snapshot()), pinnedClasses,
        px, paletteY, pw, paletteH
      )
      if clickedClass then
        selectedClass = clickedClass
      end

      G2.setColor(0.5, 0.65, 1.0)
      G2.print("SELECTED: " .. selectedClass, px, q4y + q4h - 18)
    end

    local botY = H - 44
    G2.setColor(0.35, 0.40, 0.55)
    G2.line(4, botY, SIDEBAR_W - 4, botY)
    botY = botY + 4

    local ops = #model.ops
    local undoLabel = ops > 0 and ("UNDO " .. ops) or "UNDO"
    if ui:button("SAVE", sx, botY, 70, 20, {centered = true}) then
      saved()
    end
    if ui:button(undoLabel, sx + 76, botY, sw - 70, 20, {centered = true}) then
      if model:undo() then injectLive(); status("undo") end
    end

    if statusMsg and statusTime > 0 then
      local alpha = math.min(statusTime, 1.0)
      G2.setColor(1, 1, 0.5, alpha * 0.9)
      G2.print(statusMsg, sx, H - 18)
    end

    -- Only unsaved-change/error prompts live in the editor. Folder selection
    -- belongs to the operating system.
    if modalEvents then
      ui.clicked, ui.rightClicked, ui.scrollDy = unpack(modalEvents)
    end
    if ui._modal == "class" then
      ui._classEditor:draw(ui, model, function(name)
        selectedClass = name
        injectLive()
        status("Class updated: " .. name)
      end, closeModal)
    elseif ui._modal == "furniture" then
      ui._furnitureEditor:draw(ui,model,function(name)
        injectLive()
        if saved() then status("Asset saved: "..name) end
      end,closeModal)
      local asset=ui._furnitureEditor
      if asset and asset.revision~=furniture.previewRevision then
        injectLive(asset:previewProfile())
        furniture.previewRevision=asset.revision
        furniture.previewActive=true
      end
    elseif ui._modal then
      local sw2, sh2 = ui:modalOverlay()
      local bw, bh = math.min(520, sw2 - 24), 180
      local bx, by = (sw2 - bw) / 2, (sh2 - bh) / 2
      G2.setColor(0.12, 0.14, 0.18)
      G2.rectangle("fill", bx, by, bw, bh)
      G2.setColor(0.9, 0.9, 0.9)
      if ui._modal == "unsaved" then
        G2.printf("Save changes to " .. session.label .. "?", bx+12, by+12, bw-24)
        if ui:button("Save", bx+12, by+bh-32, 80, 22) then
          if saved() then
            local action = pendingAction
            pendingAction = nil
            closeModal()
            action()
          end
        elseif ui:button("Discard", bx+104, by+bh-32, 80, 22) then
          local action = pendingAction
          pendingAction = nil
          closeModal()
          action()
        elseif ui:button("Cancel", bx+196, by+bh-32, 80, 22) then
          pendingAction = nil
          closeModal()
        end
      elseif ui._modal == "delete" then
        G2.printf("Move " .. session.label .. " to the system Trash?"
          .. (session:isDirty() and " Unsaved edits will be discarded." or ""),
          bx+12, by+12, bw-24)
        if ui:button("Move to Trash", bx+12, by+bh-32, 120, 22) then
          -- Prepare the replacement document before removing the current one.
          local original, err = ModManager.loadProfile(V.mod.path)
          if not original then
            ui._dialogError = tostring(err)
          else
            local ok
            ok, err = ModManager.trashProject(session.path, V.mod.path)
            if ok then
              session:activate(ModManager.absolutePath(V.mod.path), original)
              closeModal()
              activated()
              status("Project moved to system Trash")
            else
              ui._dialogError = tostring(err)
            end
          end
        elseif ui:button("Cancel", bx+144, by+bh-32, 80, 22) then
          closeModal()
        end
      else
        G2.printf("Project operation failed", bx+12, by+12, bw-24)
        if ui:button("Close", bx+12, by+bh-32, 80, 22) then closeModal() end
      end
      if ui._dialogError then
        G2.setColor(1, 0.65, 0.55)
        G2.printf(ui._dialogError, bx+12, by+48, bw-24)
      end
    end

    clickX, clickY, clickBtn = nil, nil, nil
    ui:endFrame()
  end

  love.mousepressed = function(x, y, button, istouch, presses)
    if camActive then return end
    ui:mousepressed(x, y, button)
    clickX, clickY, clickBtn = x, y, button
    mouseDown = (button == 1)
  end

  love.mousemoved = function(x, y, dx, dy, istouch)
    if camActive then
      camDX = camDX + (dx or 0)
      camDY = camDY + (dy or 0)
      return
    end
    ui:mousemoved(x, y)
  end

  love.mousereleased = function(x, y, button, istouch, presses)
    if camActive then return end
    ui:mousereleased(x, y, button)
    if button == 1 then mouseDown = false end
  end

  love.wheelmoved = function(x, y)
    if camActive then
      camDist = camDist - y * 5
      camDist = math.max(20, math.min(500, camDist))
      return
    end
    ui:wheelmoved(x, y)
  end

  love.textinput = function(text)
    local field = ui._textInputState
    if (ui._modal == "class" or ui._modal == "furniture") and field and field.focused then
      field._char = (field._char or "") .. text:gsub("[^%w_]", "")
    end
  end

  love.keypressed = function(key, scancode, isrepeat)
    if ui._modal then
      local field = ui._textInputState
      if ui._modal=='furniture' and not (field and field.focused) and love.keyboard.isDown('lctrl','rctrl') then
        if key=='z' then ui._furnitureEditor:undo(); return end
        if key=='y' then ui._furnitureEditor:redo(); return end
      end
      if (ui._modal == "class" or ui._modal == "furniture") and field and field.focused then
        if key == "return" or key == "kpenter" then field._enter = true
        elseif key == "backspace" then field._back = true end
      end
      if key == "escape" then pendingAction = nil; closeModal() end
      return
    end
    if key == "tab" then
      camActive = not camActive
      love.mouse.setGrabbed(camActive)
      if camActive and not camInit then
        if w.map then
          camX = w.map.width * 8
          camZ = w.map.height * 8
        end
        camInit = true
      end
      return
    end
    if camActive then return end
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
    if key == "escape" then
      requestAction(function() love.event.quit() end)
    elseif key == "1" then
      activeTool = "select"
    elseif key == "2" then
      activeTool = "paint"
    elseif key == "z" and ctrl then
      if model:undo() then injectLive(); status("undo") end
    elseif key == "y" and ctrl then
      if model:redo() then injectLive(); status("redo") end
    elseif key == "s" and ctrl then
      if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
        pendingNative = "save_as"
      else
        saved()
      end
    elseif key == "left" then
      tsetIdx = math.max(1, tsetIdx - 1); mapIdx = 1
      pendingMap = curMapId()
    elseif key == "right" then
      tsetIdx = math.min(#tilesetIds, tsetIdx + 1); mapIdx = 1
      pendingMap = curMapId()
    elseif key == "up" then
      local tm = mapsByTset[curTsetId()] or {}
      mapIdx = math.max(1, mapIdx - 1)
      pendingMap = curMapId()
    elseif key == "down" then
      local tm = mapsByTset[curTsetId()] or {}
      mapIdx = math.min(#tm, mapIdx + 1)
      pendingMap = curMapId()
    end
  end

  injectLive()
  while true do
    if pendingNative then
      local mode = pendingNative
      pendingNative = nil
      local path, err = FolderPicker.open()
      -- Clear the triggering press before the desktop returns control.
      ui.clicked, ui.rightClicked, ui.mouseDown = false, false, false
      clickX, clickY, clickBtn, mouseDown = nil, nil, nil, false
      if path then
        local function applySelection()
          local ok, reason
          if mode == "new" then
            ok, reason = session:createInDirectory(path, V.mod.path, w, true)
          elseif mode == "save_as" then
            ok, reason = session:saveAsInDirectory(path, V.mod.path, w)
          else
            ok, reason = session:open(path, true)
          end
          if ok then
            activated()
          else
            ui._modal, ui._dialogError = "error", tostring(reason)
          end
        end
        if mode == "save_as" then applySelection() else requestAction(applySelection) end
      elseif err then
        ui._modal, ui._dialogError = "error", err
      end
    end
    if statusTime > 0 then statusTime = statusTime - 1/60 end

    if camActive then
      local SENS = 0.15
      camAz = camAz - camDX * SENS
      camEl = camEl - camDY * SENS
      camEl = math.max(-50, math.min(70, camEl))
      camDX, camDY = 0, 0

      local speed = 8
      local azr = camAz * math.pi / 180
      local fwdX, fwdZ = math.sin(azr), math.cos(azr)
      local rightX, rightZ = -math.cos(azr), math.sin(azr)
      local mx, mz = 0, 0
      if love.keyboard.isDown("w") then mx = mx + fwdX; mz = mz + fwdZ end
      if love.keyboard.isDown("s") then mx = mx - fwdX; mz = mz - fwdZ end
      if love.keyboard.isDown("a") then mx = mx - rightX; mz = mz - rightZ end
      if love.keyboard.isDown("d") then mx = mx + rightX; mz = mz + rightZ end
      if love.keyboard.isDown("q") then camH = camH + speed * 0.5 end
      if love.keyboard.isDown("e") then camH = camH - speed * 0.5 end
      camX = camX + mx * speed
      camZ = camZ + mz * speed
    end

    if pendingMap then
      local mapId = pendingMap
      pendingMap = nil
      if w.mapScenes then w.mapScenes[mapId] = 1 end
      pcall(function() w:setMap(mapId, 6, 5, "up") end)
      for _ = 1, 10 do coroutine.yield() end

      injectLive()
    end
    coroutine.yield()
  end
end
