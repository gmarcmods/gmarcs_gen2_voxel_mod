-- A fresh cache for each Scene.render. Shadows, water and scenery share the
-- same atlas resolution without retaining stale palettes between frames.
local C={enabled=true}
function C.wrap(load)
 if not C.enabled then return load end
 local values={}
 return function(map)
  local image=values[map]
  if image then return image end
  image=load(map)
  if image then values[map]=image end
  return image
 end
end
return C
