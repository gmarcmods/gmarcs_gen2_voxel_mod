-- ModManager: discover, create, load, and save voxel mods.
--
-- Mods live as sibling directories alongside voxel_mod/ in the workspace.
-- Each mod has its own manifest.json and data/voxel_heights.lua profile.
-- Code (lib/, tools/, main.lua) is symlinked from voxel_mod/ to avoid
-- duplication.

local ModManager = {}

-- The editor's last project is a user preference, kept in Love's save
-- directory rather than in any mod.  This keeps opening a project from
-- changing the project itself and works regardless of where the project
-- folder lives on disk.
local LAST_PROJECT_FILE = "editor_last_project.txt"

function ModManager.lastProjectFile()
  return LAST_PROJECT_FILE
end

function ModManager.loadLastProject(fs)
  fs = fs or (love and love.filesystem)
  if not fs or type(fs.read) ~= "function" then return nil end
  local ok, value = pcall(fs.read, LAST_PROJECT_FILE)
  if not ok or type(value) ~= "string" then return nil end
  value = value:gsub("\r", ""):gsub("\n+$", "")
  if value == "" or value:find("\n", 1, true) or value:find("\0", 1, true) then return nil end
  return value
end

function ModManager.saveLastProject(path, fs)
  fs = fs or (love and love.filesystem)
  if not fs or type(fs.write) ~= "function" or type(path) ~= "string"
     or path == "" or path:find("[\r\n%z]") then
    return false, "invalid last project path"
  end
  local ok, result = pcall(fs.write, LAST_PROJECT_FILE, path)
  if not ok or result == false then
    return false, tostring(result or "could not save last project")
  end
  return true
end
local editorModel

local function getEditorModel()
  if editorModel then return editorModel end
  local source = debug.getinfo(1, "S").source or ""
  local file = source:sub(1, 1) == "@" and source:sub(2) or nil
  local dir = file and file:match("^(.*)/[^/]+$")
  if not dir then return nil, "cannot locate EditorModel.lua" end
  local ok, model = pcall(dofile, dir .. "/EditorModel.lua")
  if not ok then return nil, model end
  editorModel = model
  return model
end

local function validateProfileClasses(model, profile)
  -- Profiles from before custom classes were introduced omit this field.
  if profile.classes == nil then return true end
  local ok, valid, err = pcall(function()
    return model.new(profile):validateClasses(profile)
  end)
  if not ok then return false, "class validation failed: " .. tostring(valid) end
  if not valid then return false, "invalid classes: " .. tostring(err) end
  return true
end

local okLfs, lfs = pcall(require, "lfs")
if not okLfs then lfs = nil end
local okFfi, ffi = pcall(require, "ffi")
if not okFfi then ffi = nil end

local native = {}
if ffi then
  if ffi.os == "Windows" then
    pcall(ffi.cdef, "char *_getcwd(char *, int);")
  else
    pcall(ffi.cdef, [[
      char *getcwd(char *, unsigned long);
      typedef struct { unsigned long long d_ino; long long d_off;
        unsigned short d_reclen; unsigned char d_type; char d_name[256];
      } mm_dirent;
      void *opendir(const char *);
      mm_dirent *readdir(void *);
      int closedir(void *);
      int mkdir(const char *, unsigned int);
      int symlink(const char *, const char *);
      char *realpath(const char *, char *);
    ]])
  end
end

local function currentDir()
  if lfs then return lfs.currentdir() end
  if ffi and ffi.os ~= "Windows" then
    local buf = ffi.new("char[4096]")
    local p = ffi.C.getcwd(buf, 4096)
    if p ~= nil then return ffi.string(p) end
  end
  return "."
end

local function isDirectory(path)
  if lfs then
    local a = lfs.attributes(path)
    return a and a.mode == "directory"
  end
  if ffi and ffi.os ~= "Windows" then
    local dir = ffi.C.opendir(path)
    if dir == nil then return false end
    ffi.C.closedir(dir)
    return true
  end
  return false
end

local function exists(path)
  if isDirectory(path) then return true end
  local f = io.open(path, "rb")
  if not f then return false end
  f:close()
  return true
end

local function absolutePath(path)
  if type(path) ~= "string" or path == "" then return nil end
  if path:sub(1, 1) ~= "/" then
    local cwd = currentDir()
    path = cwd .. "/" .. path
  end
  path = path:gsub("/+", "/")
  local parts = {}
  for part in path:gmatch("[^/]+") do
    if part == ".." then
      if #parts > 0 then table.remove(parts) end
    elseif part ~= "." then
      parts[#parts + 1] = part
    end
  end
  local normalized = "/" .. table.concat(parts, "/")
  if ffi and ffi.os ~= "Windows" and exists(normalized) then
    local buf = ffi.new("char[4096]")
    local resolved = ffi.C.realpath(normalized, buf)
    if resolved ~= nil then return ffi.string(resolved) end
  end
  return normalized
end

ModManager.absolutePath = absolutePath

local function info(path)
  if lfs then return lfs.attributes(path) end
  if isDirectory(path) then return { mode = "directory" } end
  if exists(path) then return { mode = "file" } end
  return nil
end

local function mkdir(path)
  if info(path) then
    return info(path).mode == "directory" and true or nil,
           info(path).mode == "directory" and nil or "path exists"
  end
  local parent = path:match("^(.*)/[^/]+$")
  if parent and parent ~= path then
    local ok, err = mkdir(parent)
    if not ok and not info(parent) then return nil, err end
  end
  local ok, err
  if lfs then
    ok, err = lfs.mkdir(path)
  elseif ffi and ffi.os ~= "Windows" then
    ok = ffi.C.mkdir(path, 493) == 0
  end
  if not ok and not info(path) then return nil, err or "cannot create directory" end
  return true
end

local function writeFile(path, content)
  local f, err = io.open(path, "wb")
  if not f then return nil, err end
  local ok, werr = f:write(content)
  f:close()
  if not ok then return nil, werr or "write failed" end
  return true
end

local function readFile(path)
  local f, err = io.open(path, "rb")
  if not f then return nil, err end
  local content = f:read("*a")
  f:close()
  return content
end

local function nativeSymlink(source, destination)
  if not ffi then return nil, "native symlink support unavailable" end
  if ffi.os == "Windows" then
    pcall(ffi.cdef, "int CreateSymbolicLinkA(const char *, const char *, unsigned long);")
    local made = pcall(function() return ffi.C.CreateSymbolicLinkA end)
    if not made then return nil, "native symlink support unavailable" end
    if ffi.C.CreateSymbolicLinkA(source, destination, 0) == 0 then
      return nil, "cannot create symlink " .. destination
    end
  else
    local made = pcall(function() return ffi.C.symlink end)
    if not made or ffi.C.symlink(source, destination) ~= 0 then
      return nil, "cannot create symlink " .. destination
    end
  end
  return true
end

-- Derive the workspace root from a mod path.
-- A mod path looks like /..../gold_voxel/voxel_mod or the symlink target
-- /..../gold_voxel/gen1recomp/mods/voxel_mod.  We walk up until we find
-- a directory that is NOT "mods" or "voxel_mod" and contains sibling dirs.
function ModManager.resolveWorkspace(modPath)
  local p = absolutePath(modPath):gsub("/+$", "")
  -- If we're inside gen1recomp/mods/, walk up to the workspace
  local workspace = p:match("^(.+)/gen1recomp/mods/[^/]+$")
  if workspace then return workspace end
  -- If we're directly in the workspace (e.g. ../voxel_mod)
  workspace = p:match("^(.+)/[^/]+$")
  return workspace or p
end

-- Parse a JSON file.  Returns table or nil.
local function readJson(path)
  local raw = readFile(path)
  if not raw then return nil end
  local ok, Json = pcall(require, "src.link.Json")
  if not ok or not Json then return nil end
  local decoded, err = Json.decode(raw)
  return decoded, err
end

-- Minimal JSON encoder for manifest writing.
local function writeJson(path, tbl)
  local ok, Json = pcall(require, "src.link.Json")
  if not ok or not Json then return nil, "JSON encoder unavailable" end
  local encoded, err = pcall(Json.encode, tbl)
  if not encoded then return nil, err end
  return writeFile(path, err)
end

function ModManager.listDirectories(nativePath)
  nativePath = absolutePath(nativePath)
  local out = {}
  if not (nativePath and isDirectory(nativePath)) then return out end
  if lfs then
    for name in lfs.dir(nativePath) do
      if name ~= "." and name ~= ".." and name:sub(1, 1) ~= "." then
        local path = nativePath .. "/" .. name
        if isDirectory(path) then out[#out + 1] = { name = name, path = path } end
      end
    end
  elseif ffi and ffi.os ~= "Windows" then
    local dir = ffi.C.opendir(nativePath)
    if dir == nil then return out end
    while true do
      local ent = ffi.C.readdir(dir)
      if ent == nil then break end
      local name = ffi.string(ent.d_name)
      if name ~= "." and name ~= ".." and name:sub(1, 1) ~= "." then
        local path = nativePath .. "/" .. name
        if isDirectory(path) then out[#out + 1] = { name = name, path = path } end
      end
    end
    ffi.C.closedir(dir)
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

local function listEntries(nativePath)
  local out = {}
  if not isDirectory(nativePath) then return out end
  if lfs then
    for name in lfs.dir(nativePath) do
      if name ~= "." and name ~= ".." then
        out[#out + 1] = { name = name, path = nativePath .. "/" .. name }
      end
    end
  elseif ffi and ffi.os ~= "Windows" then
    local dir = ffi.C.opendir(nativePath)
    if dir == nil then return out end
    while true do
      local ent = ffi.C.readdir(dir)
      if ent == nil then break end
      local name = ffi.string(ent.d_name)
      if name ~= "." and name ~= ".." then
        out[#out + 1] = { name = name, path = nativePath .. "/" .. name }
      end
    end
    ffi.C.closedir(dir)
  end
  return out
end

local function directoryEmpty(nativePath)
  if lfs then
    for name in lfs.dir(nativePath) do
      if name ~= "." and name ~= ".." then return false end
    end
    return true
  end
  if ffi and ffi.os ~= "Windows" then
    local dir = ffi.C.opendir(nativePath)
    if dir == nil then return false end
    local empty = true
    while true do
      local ent = ffi.C.readdir(dir)
      if ent == nil then break end
      local name = ffi.string(ent.d_name)
      if name ~= "." and name ~= ".." then empty = false; break end
    end
    ffi.C.closedir(dir)
    return empty
  end
  return false
end

-- Scan sibling directories of workspacePath for mods.
-- Returns: { {name, displayName, path, manifest, hasProfile}, ... }
function ModManager.discoverMods(workspacePath)
  workspacePath = absolutePath(workspacePath)
  local mods = {}
  for _, entry in ipairs(ModManager.listDirectories(workspacePath)) do
    if entry.name ~= "gen1recomp" then
      local path = entry.path
      local manifest = readJson(path .. "/manifest.json")
      if type(manifest) == "table" and type(manifest.id) == "string" then
        mods[#mods + 1] = {
          name = manifest.id,
          displayName = manifest.displayName or manifest.name or entry.name,
          path = path,
          manifest = manifest,
          hasProfile = info(path .. "/data/voxel_heights.lua") ~= nil,
        }
      end
    end
  end
  table.sort(mods, function(a, b) return a.name < b.name end)
  return mods
end

-- Scaffold a new mod directory.
-- Returns (modPath, err).
local function scaffold(modPath, modName, gameId, world, sourcePath, displayName, allowExistingEmpty)
  gameId = gameId or "gen2"
  if not modName or not modName:match("^[%a_][%w_]*$") then
    return nil, "invalid mod name: " .. tostring(modName)
  end
  if info(modPath) then
    if not (allowExistingEmpty and isDirectory(modPath) and directoryEmpty(modPath)) then
      return nil, "directory already exists: " .. modPath
    end
  end
  sourcePath = absolutePath(sourcePath)
  if not sourcePath or not info(sourcePath) then
    return nil, "source mod not found: " .. tostring(sourcePath)
  end

  -- Create directory tree
  local ok, err = mkdir(modPath .. "/data/map_overrides")
  if not ok then return nil, "cannot create project: " .. tostring(err) end

  -- Write manifest.json
  local manifest = {
    id = modName:upper(),
    name = displayName or modName,
    version = "0.1.0",
    api = 2,
    entry = "main.lua",
    games = { gameId },
    profile = "content",
    category = "GRAPHICS",
    priority = 100,
    dependencies = {},
    optional_dependencies = {},
    conflicts = {},
    permissions = { "engine_internals" },
    affects_link = false,
    description = "Voxel mod created by the editor.",
    managed_by_editor = true,
  }
  local runtimeManifest = readJson(sourcePath .. '/manifest.json')
  if runtimeManifest and runtimeManifest.optional_imports then
    manifest.optional_imports = runtimeManifest.optional_imports
  end
  ok, err = writeJson(modPath .. "/manifest.json", manifest)
  if not ok then
    return nil, "cannot write manifest: " .. tostring(err)
  end

  -- Symlink runtime code from the selected source project.  Data stays local
  -- so each project can be edited independently.
  local function tryLink(src, dst)
    return nativeSymlink(src, dst)
  end
  for _, name in ipairs({"lib", "tools", "assets"}) do
    if info(sourcePath .. "/" .. name) then
      ok, err = tryLink(sourcePath .. "/" .. name, modPath .. "/" .. name)
      if not ok then return nil, err end
    end
  end
  ok, err = tryLink(sourcePath .. "/main.lua", modPath .. "/main.lua")
  if not ok then return nil, err end

  -- Runtime data is shared with the source project, except for the profile
  -- and map overrides which belong to this project.  Link only entries that
  -- exist and never replace anything in the newly-created data directory.
  local sourceData = sourcePath .. "/data"
  if isDirectory(sourceData) then
    for _, entry in ipairs(listEntries(sourceData)) do
      if entry.name ~= "voxel_heights.lua" and entry.name ~= "map_overrides"
         and not info(modPath .. "/data/" .. entry.name) then
        ok, err = tryLink(entry.path, modPath .. "/data/" .. entry.name)
        if not ok then return nil, err end
      end
    end
  end

  -- Scan tilesets from the live world and build a default profile
  local profileLines = {
    "-- Voxel shape profile for " .. modName .. ".",
    "-- Auto-generated with tileset scanning.",
    "return {",
    "  version = 1,",
    "  heights = {",
    "    ground = 0, water = -2, wall = 16, ledge = 6, roof = 28,",
    "    bed = 7, stool = 8, counter = 8, backrest = 12, table = 12,",
    "    desk = 24, prop = 16, cutout = 16, bike = 16, planter = 32,",
    "    sapling = 16, relief = 3, bookcase = 32, cylinder = 16,",
    "    stair_e = 16, stair_w = 16, stair_n = 16, stair_down_e = 16, stair_down_w = 16, stair_down_n = 16,",
    "    billboard = 16, console = 16, signpost = 16, post = 16,",
    "    can = 9, stump = 16, canopy = 32, grass = 0, fence = 10,",
    "    sign = 12, cliff = 32, void = 0, tree = 16,",
    "  },",
    "  tilesets = {",
  }

  -- Scan all tilesets from the world
  local tilesetIds = {}
  if world and world.maps then
    local seen = {}
    for mapId, def in pairs(world.maps) do
      if type(def) == "table" and type(def.tileset) == "string"
         and not seen[def.tileset] then
        seen[def.tileset] = true
        tilesetIds[#tilesetIds + 1] = def.tileset
      end
    end
    table.sort(tilesetIds)
  end

  -- Add each tileset with empty class groups (user fills in via editor)
  for _, tsId in ipairs(tilesetIds) do
    profileLines[#profileLines + 1] = "    " .. tsId .. " = {"
    profileLines[#profileLines + 1] = "    },"
  end

  profileLines[#profileLines + 1] = "  },"
  profileLines[#profileLines + 1] = "  buildings = {"
  profileLines[#profileLines + 1] = "  },"
  profileLines[#profileLines + 1] = "}"
  profileLines[#profileLines + 1] = ""

  ok, err = writeFile(modPath .. "/data/voxel_heights.lua", table.concat(profileLines, "\n"))
  if not ok then return nil, "cannot write profile: " .. tostring(err) end

  -- Write override registry
  local initOverride = table.concat({
    "-- Per-map override registry.",
    "-- Maps: mapId -> override file path (relative to mod root).",
    "return {}",
    "",
  }, "\n")
  ok, err = writeFile(modPath .. "/data/map_overrides/init.lua", initOverride)
  if not ok then return nil, "cannot write override registry: " .. tostring(err) end

  return modPath
end

function ModManager.createMod(workspacePath, modName, gameId, world, sourcePath)
  if not modName or not modName:match("^[%a_][%w_]*$") then
    return nil, "invalid mod name: " .. tostring(modName)
  end
  workspacePath = absolutePath(workspacePath)
  if not workspacePath then return nil, "invalid workspace path" end
  sourcePath = sourcePath or (workspacePath .. "/voxel_mod")
  return scaffold(workspacePath .. "/" .. modName, modName, gameId,
                  world, sourcePath)
end

-- Initialize a project in the exact existing directory selected by a native
-- folder picker.  We refuse non-empty directories so a picker mistake cannot
-- overwrite unrelated files or an existing project.
function ModManager.createInDirectory(selectedPath, sourcePath, world, gameId)
  selectedPath = absolutePath(selectedPath)
  if not selectedPath or not isDirectory(selectedPath) then
    return nil, "selected folder does not exist"
  end
  if not directoryEmpty(selectedPath) then
    return nil, "selected folder is not empty"
  end
  local base = selectedPath:match("([^/]+)$") or ""
  local id = base:gsub("[^%w_]", "_")
  if id == "" or not id:match("^[%a_]") then id = "_" .. id end
  if not id:match("^[%a_][%w_]*$") then
    return nil, "selected folder has no usable project name"
  end
  return scaffold(selectedPath, id, gameId, world, sourcePath, base, true)
end

-- Load a mod's profile from data/voxel_heights.lua.
-- Returns: profile table or nil, err.
function ModManager.loadProfile(modPath)
  modPath = absolutePath(modPath)
  local path = modPath .. "/data/voxel_heights.lua"
  local src, readErr = readFile(path)
  if not src then return nil, "profile not found: " .. path .. ": " .. tostring(readErr) end
  local fn, err = load(src, "@" .. path)
  if not fn then return nil, "syntax error: " .. tostring(err) end
  local ok, result = pcall(fn)
  if not ok then return nil, "runtime error: " .. tostring(result) end
  if type(result) ~= "table" then
    return nil, "profile must return a table, got " .. type(result)
  end
  for _, key in ipairs({"heights", "tilesets", "buildings"}) do
    if type(result[key]) ~= "table" then
      return nil, "profile " .. key .. " must be a table"
    end
  end
  if result.classes ~= nil then
    local model, modelErr = getEditorModel()
    if not model or type(model.new) ~= "function"
       or type(model.validateClasses) ~= "function" then
      return nil, "EditorModel class validator unavailable: " .. tostring(modelErr)
    end
    local valid, classErr = validateProfileClasses(model, result)
    if not valid then return nil, classErr end
  end
  return result
end

local function pathIsOrInside(path, parent)
  return path == parent or path:sub(1, #parent + 1) == parent .. "/"
end

local function shellQuote(path)
  return "'" .. tostring(path):gsub("'", "'\\''") .. "'"
end

local function commandSucceeded(a, b, c)
  if a == true then return true end
  if type(a) == "number" then return a == 0 end
  return a == true and (b == nil or b == "exit") and (c == nil or c == 0)
end

-- Send an editor-created project to the operating system Trash.  The runner
-- is injectable for tests and callers that provide their own host integration;
-- it receives one fully quoted command and must return os.execute-style status.
function ModManager.trashProject(projectPath, protectedSourcePath, runner)
  projectPath = absolutePath(projectPath)
  if not projectPath or not isDirectory(projectPath) then
    return false, "project directory not found"
  end
  local manifest = readJson(projectPath .. "/manifest.json")
  if type(manifest) ~= "table" or manifest.managed_by_editor ~= true then
    return false, "refusing to trash unmanaged project"
  end
  local profile, profileErr = ModManager.loadProfile(projectPath)
  if not profile then return false, "refusing invalid project: " .. tostring(profileErr) end

  if protectedSourcePath then
    local source = absolutePath(protectedSourcePath)
    if source and pathIsOrInside(source, projectPath) then
      return false, "refusing to trash source project or its ancestor"
    end
  end

  runner = runner or function(command) return os.execute(command) end
  local command = "gio trash -- " .. shellQuote(projectPath)
  local ok, a, b, c = pcall(runner, command, projectPath)
  if not ok then return false, "trash command failed: " .. tostring(a) end
  if not commandSucceeded(a, b, c) then
    return false, "trash command failed"
  end
  if isDirectory(projectPath) or info(projectPath) then
    return false, "trash command succeeded but project remains"
  end
  return true
end

-- Save a fused spec to a mod's data/voxel_heights.lua.
-- spec should be the output of EditorModel:fuse().
function ModManager.saveProfile(modPath, spec, serializeFn)
  modPath = absolutePath(modPath)
  local path = modPath .. "/data/voxel_heights.lua"
  if type(spec) ~= "table" then return false, "profile must be a table" end
  local model, modelErr = getEditorModel()
  if not model or type(model.new) ~= "function" then
    return false, "EditorModel serializer unavailable: " .. tostring(modelErr)
  end
  if spec.classes ~= nil then
    local valid, classErr = validateProfileClasses(model, spec)
    if not valid then return false, classErr end
  end
  local instance = model.new(spec)
  if serializeFn then
    instance.serialize = function() return serializeFn(spec) end
  end
  return instance:save(path)
end

-- Load the override registry for a mod.
-- Returns: table { mapId -> relativePath } or empty table.
function ModManager.loadOverrideRegistry(modPath)
  local path = modPath .. "/data/map_overrides/init.lua"
  local f = io.open(path, "r")
  if not f then return {} end
  local src = f:read("*a")
  f:close()
  local fn = load(src, "@" .. path)
  if not fn then return {} end
  local ok, result = pcall(fn)
  if not ok or type(result) ~= "table" then return {} end
  return result
end

-- Save the override registry.
function ModManager.saveOverrideRegistry(modPath, registry)
  local path = modPath .. "/data/map_overrides/init.lua"
  local parts = {
    "-- Per-map override registry.",
    "-- Maps: mapId -> override file path (relative to mod root).",
    "return {",
  }
  local keys = {}
  for k in pairs(registry) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    parts[#parts + 1] = ('  [%q] = %q,'):format(k, registry[k])
  end
  parts[#parts + 1] = "}"
  parts[#parts + 1] = ""
  local f = io.open(path, "w")
  if not f then return false end
  f:write(table.concat(parts, "\n"))
  f:close()
  return true
end

-- Load a specific map override.
-- Returns: override table or nil.
function ModManager.loadMapOverride(modPath, registry, mapId)
  local rel = registry[mapId]
  if not rel then return nil end
  local path = modPath .. "/" .. rel
  local f = io.open(path, "r")
  if not f then return nil end
  local src = f:read("*a")
  f:close()
  local fn = load(src, "@" .. path)
  if not fn then return nil end
  local ok, result = pcall(fn)
  if not ok or type(result) ~= "table" then return nil end
  return result
end

-- Save a map override.
function ModManager.saveMapOverride(modPath, registry, mapId, override)
  local rel = "data/map_overrides/" .. mapId .. ".lua"
  local path = modPath .. "/" .. rel
  local parts = {
    "-- Per-map override for " .. mapId .. ".",
    "-- Tileset customizations for this specific map context.",
    "return {",
  }
  if override.tilesets then
    parts[#parts + 1] = "  tilesets = {"
    local tkeys = {}
    for k in pairs(override.tilesets) do tkeys[#tkeys + 1] = k end
    table.sort(tkeys)
    for _, tsetId in ipairs(tkeys) do
      parts[#parts + 1] = ("    [%q] = {"):format(tsetId)
      local tsData = override.tilesets[tsetId]
      local ckeys = {}
      for k in pairs(tsData) do ckeys[#ckeys + 1] = k end
      table.sort(ckeys)
      for _, class in ipairs(ckeys) do
        local tiles = tsData[class]
        if type(tiles) == "table" then
          local items = {}
          for _, id in ipairs(tiles) do items[#items + 1] = tostring(id) end
          parts[#parts + 1] = ("      %s = { %s },"):format(
            class, table.concat(items, ", "))
        end
      end
      parts[#parts + 1] = "    },"
    end
    parts[#parts + 1] = "  },"
  end
  if override.heights then
    parts[#parts + 1] = "  heights = {"
    local hkeys = {}
    for k in pairs(override.heights) do hkeys[#hkeys + 1] = k end
    table.sort(hkeys)
    for _, k in ipairs(hkeys) do
      parts[#parts + 1] = ("    %s = %s,"):format(k, tostring(override.heights[k]))
    end
    parts[#parts + 1] = "  },"
  end
  parts[#parts + 1] = "}"
  parts[#parts + 1] = ""
  local f = io.open(path, "w")
  if not f then return false end
  f:write(table.concat(parts, "\n"))
  f:close()
  -- Update registry
  registry[mapId] = rel
  ModManager.saveOverrideRegistry(modPath, registry)
  return true
end

-- Minimal serializer for the profile spec.
function ModManager._serialize(spec)
  local parts = {}
  parts[#parts + 1] = "-- Voxel shape profile."
  parts[#parts + 1] = "-- Generated by the voxel editor."
  parts[#parts + 1] = "return {"
  parts[#parts + 1] = ("  version = %d,"):format(spec.version or 1)

  -- heights
  parts[#parts + 1] = "  heights = {"
  if spec.heights then
    local keys = {}
    for k in pairs(spec.heights) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
      parts[#parts + 1] = ("    %s = %s,"):format(k, tostring(spec.heights[k]))
    end
  end
  parts[#parts + 1] = "  },"

  -- tilesets
  parts[#parts + 1] = "  tilesets = {"
  if spec.tilesets then
    local tkeys = {}
    for k in pairs(spec.tilesets) do tkeys[#tkeys + 1] = k end
    table.sort(tkeys)
    for _, tsetId in ipairs(tkeys) do
      parts[#parts + 1] = ("    %s = {"):format(tsetId)
      local tsData = spec.tilesets[tsetId]
      if type(tsData) == "table" then
        -- Standard class groups (sorted arrays)
        local ckeys = {}
        for k, v in pairs(tsData) do
          if type(v) == "table" then ckeys[#ckeys + 1] = k end
        end
        table.sort(ckeys)
        for _, class in ipairs(ckeys) do
          local tiles = tsData[class]
          if #tiles > 0 then
            local items = {}
            for _, id in ipairs(tiles) do items[#items + 1] = tostring(id) end
            parts[#parts + 1] = ("      %s = { %s },"):format(
              class, table.concat(items, ", "))
          end
        end
        -- Non-table values (heights, art, spray, etc.)
        local skeys = {}
        for k, v in pairs(tsData) do
          if type(v) ~= "table" then skeys[#skeys + 1] = k end
        end
        table.sort(skeys)
        for _, k in ipairs(skeys) do
          local v = tsData[k]
          if type(v) == "string" then
            parts[#parts + 1] = ("      %s = %q,"):format(k, v)
          elseif type(v) == "boolean" then
            parts[#parts + 1] = ("      %s = %s,"):format(k, tostring(v))
          elseif type(v) == "number" then
            parts[#parts + 1] = ("      %s = %s,"):format(k, tostring(v))
          elseif type(v) == "table" then
            -- when_below, when_above, figures, etc. — skip for minimal
            -- These are complex nested structures; the editor's own
            -- serialize() handles them.  For the minimal fallback we
            -- omit them (they'd be lost).
          end
        end
      end
      parts[#parts + 1] = "    },"
    end
  end
  parts[#parts + 1] = "  },"

  -- buildings
  parts[#parts + 1] = "  buildings = {"
  if spec.buildings then
    local bkeys = {}
    for k in pairs(spec.buildings) do bkeys[#bkeys + 1] = k end
    table.sort(bkeys)
    for _, tsetId in ipairs(bkeys) do
      parts[#parts + 1] = ("    %s = {"):format(tsetId)
      local bList = spec.buildings[tsetId]
      if type(bList) == "table" then
        for _, b in ipairs(bList) do
          parts[#parts + 1] = "      {"
          if b.id then parts[#parts + 1] = ("        id = %q,"):format(b.id) end
          -- Copy through known fields
          for _, field in ipairs({"tiles", "roofRows", "roofBack", "roofFront",
                                  "roofCycle", "slab", "frontEave", "ledge",
                                  "depth", "desk", "parts"}) do
            if b[field] ~= nil then
              parts[#parts + 1] = ("        %s = %s,"):format(
                field, tostring(b[field]))
            end
          end
          parts[#parts + 1] = "      },"
        end
      end
      parts[#parts + 1] = "    },"
    end
  end
  parts[#parts + 1] = "  },"

  parts[#parts + 1] = "}"
  parts[#parts + 1] = ""
  return table.concat(parts, "\n")
end

-- Get current mod info from the V table.
-- Returns: { id, path, mod } or nil.
function ModManager.getCurrentMod(V)
  if not V or not V.mod then return nil end
  return {
    id = V.mod.id or V.mod.name,
    path = V.mod.path,
    mod = V.mod,
  }
end

return ModManager
