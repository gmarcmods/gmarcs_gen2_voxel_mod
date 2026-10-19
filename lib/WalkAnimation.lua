-- Display-time walking cadence. Simulation may advance entire steps between
-- draws; sampling its step phase then can show the standing frame forever.
local WalkAnimation = {}
local states = setmetatable({}, { __mode = 'k' })

function WalkAnimation.pose(actor, nativePhase, nativeFlip, now, map)
  local x, y = actor.px or 0, actor.py or 0
  local state = states[actor]
  -- Slow draws and fast movement can cover any distance. A map identity
  -- change, rather than a pixel threshold, identifies a discontinuity.
  if not state or state.map ~= map then
    state = { x = x, y = y, time = now, elapsed = 0,
      phase = nativePhase, flip = nativeFlip, map = map }
    states[actor] = state
    return nativePhase, nativeFlip
  end
  local dx, dy = x - state.x, y - state.y
  local distance = math.sqrt(dx * dx + dy * dy)
  local dt = math.min(1 / 15, math.max(0, now - state.time))
  state.x, state.y, state.time = x, y, now
  if distance > 0.0001 then
    state.elapsed = state.elapsed + dt
    state.phase = math.floor(state.elapsed * 7.5) % 2
    state.flip = math.floor(state.elapsed * 3.75) % 2 == 1
  elseif not actor.moving and not (actor.voxelFreeWalk and actor.voxelFreeWalk.moving) then
    state.elapsed = 0
    state.phase, state.flip = nativePhase, nativeFlip
  end
  -- Repeated shadow/actor queries and paused simulation retain one pose.
  return state.phase, state.flip
end

return WalkAnimation
