-- Headless coverage for variable-size SpriteBillboards. Run with:
--   luajit mods/gen2/new_mod_ex/tests/test_variable_sprite_billboards.lua

local imageByName = {}
package.preload["src.render.Assets"] = function()
  return {
    image = function(path) return imageByName[path] end,
    imageData = function() return nil end,
    register = function() end,
  }
end

local queried, poseFrame, poseMirror = 0, 4, true
package.preload["src.render.SpriteRenderer"] = function()
  local SR = { WALK = { down = 3, up = 4, left = 5, right = 5 },
    STAND = { down = 0, up = 1, left = 2, right = 2 } }
  function SR.getPoseGeometry(self, facing, phase, flip)
    local frame = (self.def.walker and phase == 1)
      and SR.WALK[facing] or SR.STAND[facing]
    return { frame = frame or 0, mirror = facing == "right"
      or ((facing == "down" or facing == "up") and phase == 1 and flip) }
  end
  function SR.getFrameGeometry(self, frame)
    return makeGeometry(frame, 0, frame * 16, 16, 16, 8, 16)
  end
  return SR
end

local meshBuilds = 0
local voxel = {
  pushQuad = function(indices, n)
    local i = n * 4
    indices[#indices + 1] = i + 1
    indices[#indices + 1] = i + 2
    indices[#indices + 1] = i + 3
    indices[#indices + 1] = i + 1
    indices[#indices + 1] = i + 3
    indices[#indices + 1] = i + 4
  end,
  newMesh = function(vertices, indices)
    meshBuilds = meshBuilds + 1
    return { vertices = vertices, indices = indices }
  end,
}
local V = { require = function(name)
  assert(name == "Voxel3D")
  return voxel
end }

local SpriteBillboards = assert(loadfile("mods/gen2/new_mod_ex/lib/SpriteBillboards.lua"))(V)

local function makeGeometry(frame, x, y, width, height, anchorX, anchorY)
  local q = { viewport = { x, y, width, height } }
  function q:getViewport() return unpack(self.viewport) end
  return {
    frame = frame, x = 0, y = frame * height,
    width = width, height = height, anchorX = anchorX, anchorY = anchorY,
    quad = q,
  }
end

local function texture(path, width, height)
  imageByName[path] = { getDimensions = function() return width, height end }
end

local function near(a, b)
  assert(math.abs(a - b) < 1e-6, ("expected %.8f, got %.8f"):format(b, a))
end

local function checkUV(mesh, iw, ih, x, y, w, h)
  local v = mesh.vertices
  near(v[1][4], (x + 0.02) / iw)
  near(v[2][4], (x + w - 0.02) / iw)
  near(v[1][5], (y + h - 0.05) / ih)
  near(v[3][5], (y + 0.05) / ih)
end

-- The original one-frame-sized sheet keeps its established 16px UV frame.
texture("legacy", 16, 32)
local legacy = { image = "legacy", frames = 2 }
local legacyMesh = SpriteBillboards.mesh(legacy, 1)
assert(legacyMesh, "legacy frame did not produce a mesh")
checkUV(legacyMesh, 16, 32, 0, 16, 16, 16)
near(legacyMesh.vertices[1][1], 0)
near(legacyMesh.vertices[3][2], 16)

-- A variable 32px frame uses its quad viewport, even when legacy x/y fields
-- still describe the engine's old zero-origin/16px frame convention.
texture("large", 64, 128)
local large = { image = "large", frames = 4 }
local g = makeGeometry(3, 16, 96, 32, 32, 10, 28)
local largeMesh = SpriteBillboards.mesh(large, 3, g)
assert(largeMesh, "32px frame did not produce a mesh")
checkUV(largeMesh, 64, 128, 16, 96, 32, 32)
near(largeMesh.vertices[1][1], -2)
near(largeMesh.vertices[1][2], -4)
near(largeMesh.vertices[3][1], 30)
near(largeMesh.vertices[3][2], 28)

-- Display dimensions and anchor scale the card while UVs stay in source pixels.
local scaledDef = {
  image = "large", frames = 4, displayWidth = 16, displayHeight = 24,
  displayAnchorX = 5, displayAnchorY = 20,
}
local scaled = SpriteBillboards.mesh(scaledDef, 3, g)
assert(scaled, "scaled display geometry did not produce a mesh")
checkUV(scaled, 64, 128, 16, 96, 32, 32)
near(scaled.vertices[1][1], 3)
near(scaled.vertices[1][2], -4)
near(scaled.vertices[3][1], 19)
near(scaled.vertices[3][2], 20)

-- Image and geometry participate in the key; repeated passes reuse the mesh.
local otherTextureDef = { image = "other", frames = 4 }
texture("other", 64, 128)
local otherImageMesh = SpriteBillboards.mesh(otherTextureDef, 3, g)
assert(otherImageMesh ~= largeMesh, "different image aliased a mesh")
local g2 = makeGeometry(3, 0, 64, 32, 32, 10, 28)
local otherGeometryMesh = SpriteBillboards.mesh(large, 3, g2)
assert(otherGeometryMesh ~= largeMesh, "different frame geometry aliased a mesh")
assert(SpriteBillboards.mesh(large, 3, g) == largeMesh,
  "identical geometry did not reuse cached mesh")
local builtBeforePasses = meshBuilds
SpriteBillboards.shadowQuad(large, 3, g)
SpriteBillboards.shadowQuad(large, 3, g)
assert(meshBuilds == builtBeforePasses, "shadow passes rebuilt a mesh")

-- Pose sampling is frozen for the frame, so solid, shadow and ghost draws share
-- one renderer query and exactly the same mesh/mirror/frame tuple.
local sprite = { def = large }
function sprite:getPoseGeometry()
  queried = queried + 1
  local geometry = makeGeometry(poseFrame, 16, poseFrame * 32, 32, 32, 10, 28)
  geometry.mirror = poseMirror
  return geometry
end
SpriteBillboards.beginFrame()
local firstMesh, firstMirror, firstFrame = SpriteBillboards.pose(sprite, "left", 1, false)
for _ = 1, 3 do
  local m, mirror, frame = SpriteBillboards.pose(sprite, "left", 1, false)
  assert(m == firstMesh and mirror == firstMirror and frame == firstFrame,
    "pose snapshot differed within a frame")
end
assert(queried == 1, "pose geometry was queried more than once in a frame")
assert(firstMirror == true and firstFrame == 4, "pose mirror/frame were lost")
local buildsAfterPose = meshBuilds
SpriteBillboards.beginFrame()
poseFrame = 5
local nextMesh, _, nextFrame = SpriteBillboards.pose(sprite, "left", 0, false)
assert(queried == 2 and nextFrame == 5, "new frame did not refresh pose")
assert(nextMesh ~= firstMesh, "new pose frame reused the previous frame mesh")
assert(meshBuilds == buildsAfterPose + 1, "new pose frame did not build one mesh")

local beforeInvalidate = meshBuilds
local prior = SpriteBillboards.mesh(large, 3, g)
SpriteBillboards.invalidate()
local rebuilt = SpriteBillboards.mesh(large, 3, g)
assert(prior ~= rebuilt and meshBuilds == beforeInvalidate + 1,
  "invalidate did not rebuild cached geometry")

-- Native 16px sprites use the same frame tables without asking the renderer
-- to allocate pose geometry. All common facings and walk flips stay cached.
texture("native", 16, 96)
local nativeDef = { image = "native", frames = 6, walker = true }
local SR = require("src.render.SpriteRenderer")
local nativeSprite = { def = nativeDef, image = imageByName.native,
  getPoseGeometry = SR.getPoseGeometry, getFrameGeometry = SR.getFrameGeometry }
local function nativePose(facing, phase, flip, expectedFrame, expectedMirror)
  local m, mirror, frame = SpriteBillboards.pose(nativeSprite, facing, phase, flip)
  assert(m and frame == expectedFrame and mirror == expectedMirror,
    ("native pose %s/%d/%s returned frame=%s mirror=%s"):format(
      facing, phase, tostring(flip), tostring(frame), tostring(mirror)))
end
local nativeBuildStart = meshBuilds
nativePose("down", 0, false, 0, false)
nativePose("up", 0, false, 1, false)
nativePose("right", 0, false, 2, true)
nativePose("down", 1, true, 3, true)
nativePose("up", 1, false, 4, false)
nativePose("right", 1, false, 5, true)
local nativeWarmBuilds = meshBuilds
assert(nativeWarmBuilds == nativeBuildStart + 6, "native frames did not build once each")
for _ = 1, 4 do
  SpriteBillboards.beginFrame()
  nativePose("down", 0, false, 0, false)
  nativePose("up", 0, false, 1, false)
  nativePose("right", 0, false, 2, true)
  nativePose("down", 1, true, 3, true)
  nativePose("up", 1, false, 4, false)
  nativePose("right", 1, false, 5, true)
end
assert(meshBuilds == nativeWarmBuilds, "native poses allocated meshes after warmup")
assert(queried == 2, "native fast path queried custom pose geometry")

print("variable sprite billboard tests passed")
