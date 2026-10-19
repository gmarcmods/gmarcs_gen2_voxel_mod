-- Zone visualization colors for the voxel editor.
--
-- Each class maps to two colors:
--   auto   — gray tone shown when the class is resolved by the detector
--   painted — saturated color shown when the user pinned this class
--
-- Colors are {r, g, b} in 0-1 range, ready for love.graphics.setColor.

local ZoneColors = {}

-- Grays: subtle variations so different auto-resolved classes are
-- distinguishable but not distracting.  Brighter = more prominent.
-- Colors: saturated and distinct so painted zones clearly stand out.
ZoneColors.CLASSES = {
  ground       = { auto = {0.42,0.42,0.42}, painted = {0.20,0.80,0.20} },
  water        = { auto = {0.42,0.42,0.42}, painted = {0.20,0.40,0.90} },
  void         = { auto = {0.42,0.42,0.42}, painted = {0.50,0.10,0.50} },
  wall         = { auto = {0.42,0.42,0.42}, painted = {0.80,0.20,0.20} },
  cliff        = { auto = {0.42,0.42,0.42}, painted = {0.70,0.20,0.20} },
  ledge        = { auto = {0.42,0.42,0.42}, painted = {0.90,0.90,0.10} },
  roof         = { auto = {0.42,0.42,0.42}, painted = {0.90,0.50,0.10} },
  fence        = { auto = {0.42,0.42,0.42}, painted = {0.60,0.40,0.20} },
  tree         = { auto = {0.42,0.42,0.42}, painted = {0.10,0.60,0.10} },
  sign         = { auto = {0.42,0.42,0.42}, painted = {0.90,0.40,0.70} },
  counter      = { auto = {0.42,0.42,0.42}, painted = {0.80,0.30,0.50} },
  table        = { auto = {0.42,0.42,0.42}, painted = {0.80,0.30,0.50} },
  desk         = { auto = {0.42,0.42,0.42}, painted = {0.80,0.30,0.50} },
  bed          = { auto = {0.42,0.42,0.42}, painted = {0.90,0.40,0.70} },
  stool        = { auto = {0.42,0.42,0.42}, painted = {0.90,0.40,0.70} },
  backrest     = { auto = {0.42,0.42,0.42}, painted = {0.90,0.40,0.70} },
  prop         = { auto = {0.42,0.42,0.42}, painted = {0.20,0.70,0.70} },
  cutout       = { auto = {0.42,0.42,0.42}, painted = {0.20,0.70,0.70} },
  bike         = { auto = {0.42,0.42,0.42}, painted = {0.20,0.70,0.70} },
  planter      = { auto = {0.42,0.42,0.42}, painted = {0.20,0.70,0.70} },
  sapling      = { auto = {0.42,0.42,0.42}, painted = {0.20,0.70,0.70} },
  relief       = { auto = {0.42,0.42,0.42}, painted = {0.60,0.40,0.80} },
  bookcase     = { auto = {0.42,0.42,0.42}, painted = {0.60,0.40,0.20} },
  cylinder     = { auto = {0.42,0.42,0.42}, painted = {0.20,0.70,0.70} },
  canopy       = { auto = {0.42,0.42,0.42}, painted = {0.20,0.70,0.70} },
  stump        = { auto = {0.42,0.42,0.42}, painted = {0.60,0.40,0.20} },
  can          = { auto = {0.42,0.42,0.42}, painted = {0.60,0.40,0.20} },
  billboard    = { auto = {0.42,0.42,0.42}, painted = {0.90,0.40,0.70} },
  console      = { auto = {0.42,0.42,0.42}, painted = {0.90,0.40,0.70} },
  signpost     = { auto = {0.42,0.42,0.42}, painted = {0.90,0.40,0.70} },
  post         = { auto = {0.42,0.42,0.42}, painted = {0.90,0.40,0.70} },
  grass        = { auto = {0.42,0.42,0.42}, painted = {0.20,0.80,0.20} },
  stair_e      = { auto = {0.42,0.42,0.42}, painted = {0.90,0.90,0.10} },
  stair_n = { auto = {0.42,0.42,0.42}, painted = {0.90,0.90,0.10} },
  stair_down_n = { auto = {0.42,0.42,0.42}, painted = {0.20,0.40,0.90} },
  stair_w      = { auto = {0.42,0.42,0.42}, painted = {0.90,0.90,0.10} },
  stair_down_e = { auto = {0.42,0.42,0.42}, painted = {0.20,0.40,0.90} },
  stair_down_w = { auto = {0.42,0.42,0.42}, painted = {0.20,0.40,0.90} },
}

-- Fallback for unknown classes: neutral gray auto, magenta painted.
local FALLBACK = { auto = {0.42,0.42,0.42}, painted = {0.80,0.20,0.80} }

-- Alpha values: auto zones are subtle, painted zones are vivid.
ZoneColors.AUTO_ALPHA   = 0.15
ZoneColors.PAINTED_ALPHA = 0.35

-- Border color for dashed lines between different classes.
ZoneColors.BORDER = {1.0, 1.0, 1.0}

function ZoneColors.get(class, painted)
  local c = ZoneColors.CLASSES[class] or FALLBACK
  if painted then return c.painted end
  return c.auto
end

-- Return the full table (for iteration in overlay rendering).
function ZoneColors.all() return ZoneColors.CLASSES end

return ZoneColors
