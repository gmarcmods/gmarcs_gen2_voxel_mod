-- Trainer art is drawn on a white page by the native battle UI. Remove only
-- edge-connected paper, preserving white clothes enclosed by the outline.
local C = {}
function C.background(w, h, pixel)
  local mask, queue = {}, {}
  local function visit(x, y)
    if x < 0 or y < 0 or x >= w or y >= h then return end
    local key = y * w + x
    if mask[key] then return end
    local r, g, b, a = pixel(x, y)
    if a == 0 or (r > .83 and g > .83 and b > .83) then
      mask[key] = true
      queue[#queue + 1] = key
    end
  end
  for x = 0, w - 1 do visit(x, 0); visit(x, h - 1) end
  for y = 0, h - 1 do visit(0, y); visit(w - 1, y) end
  local head = 1
  while head <= #queue do
    local key = queue[head]; head = head + 1
    local x, y = key % w, math.floor(key / w)
    visit(x - 1, y); visit(x + 1, y); visit(x, y - 1); visit(x, y + 1)
  end
  return mask
end
local cache = setmetatable({}, {__mode = 'k'})
function C.image(original, path, trueColor)
  if not original or not path or trueColor then return original end
  if cache[original] then return cache[original] end
  local Assets = require('src.render.Assets')
  local ok, source = pcall(Assets.imageData, path)
  if not ok or not source then return original end
  local w, h = source:getDimensions()
  local data = love.image.newImageData(w, h)
  data:paste(source, 0, 0, 0, 0, w, h)
  local mask = C.background(w, h, function(x, y) return source:getPixel(x, y) end)
  for key in pairs(mask) do data:setPixel(key % w, math.floor(key / w), 0, 0, 0, 0) end
  local image = love.graphics.newImage(data)
  image:setFilter('nearest', 'nearest')
  cache[original] = image
  return image
end
return C
