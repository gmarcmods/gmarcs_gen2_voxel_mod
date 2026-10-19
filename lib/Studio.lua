-- The studio camera: a deterministic placed camera for screenshot work.
--
-- Drivers cannot aim a live camera -- they run as coroutines resumed once
-- per frame -- so every viewpoint has to be COMPUTED and handed to the
-- engine through the placed-camera seam that already exists
-- (Voxel3D.camera: { eye, focus, fov, up } -- see lib/Voxel3D.lua, "An
-- explicit camera").  While that field is set the orbit rung is ignored
-- entirely and everything downstream (the sky's ray fan, billboards,
-- project()) reads the placed pose, so a studio shot is the same render
-- path a player sees, just aimed by numbers.
--
-- Convention here is compass-style so tour scripts read like shot lists:
--   az  0 = the camera stands NORTH of the target looking south (the
--          classic overworld view; north is -z)
--   az 90 = east of it looking west, az 180 = south looking north...
--   el  = degrees ABOVE the horizon; 0 is a level shot, 90 straight down.
--   h   = the height of the AIM POINT above the ground plane (world px).
--
-- Purely computational: no love state, nothing global but Voxel3D.camera
-- on apply(), so assertions in a driver can check the exact numbers.
local V = ...

local Mat4 = V.require("Mat4")

local Studio = {}

local DEG = math.pi / 180

-- Orbit `o` around its target and return the placed-camera record.
-- o = { x, z, h, az, el, dist, fov }
--   x, z    the aim point on the ground plane, world pixels (tiles * 8)
--   h       aim height above the ground (default 8: mid-sprite)
--   dist    camera distance from the aim point, world px
--   fov     vertical fov, RADIANS (default 50deg, near the orbit's lens)
function Studio.pose(o)
  local azr = (o.az or 0) * DEG
  local elr = (o.el or 35) * DEG
  local dist = o.dist or 96
  local focus = { o.x, o.h or 8, o.z }
  local horiz = dist * math.cos(elr)
  local eye = {
    focus[1] - horiz * math.sin(azr),
    focus[2] + dist * math.sin(elr),
    focus[3] - horiz * math.cos(azr),
  }
  return { eye = eye, focus = focus,
           fov = o.fov or 50 * DEG, up = { 0, 1, 0 } }
end

-- Hand the pose to the renderer. Idempotent across frames: nothing in the
-- parked-overworld path clears Voxel3D.camera (only battles and the
-- free-roam rigs do), so setting it once per pose holds until changed.
function Studio.apply(Voxel3D, cam)
  Voxel3D.camera = cam
end

function Studio.clear(Voxel3D)
  Voxel3D.camera = nil
end

Studio.DEG = DEG
return Studio
