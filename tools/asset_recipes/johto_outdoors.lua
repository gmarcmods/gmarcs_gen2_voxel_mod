-- Checked against the installed Johto/Johto Modern atlas and tile grids.
-- These are the inherited profile's scenery rules. Johto Modern shares
-- the listed ground/sign/small-tree texels byte-for-byte, but NOT 46/47:
-- those tiles depict rock there, so its tree-wall rule must not be copied.
local function common()
  return {pins={
    ground={5,6}, -- plain path/ground texels, never little wall pillars
    water={20,88}, -- water fill and animated water source
    ledge={76}, -- low hop-down lip, except below a tall cliff course
    signpost={78,79,94,95}, -- complete board/post drawings
    flower={3}, -- flowerbed: ground plus blooms, not a solid box
    cylinder={30,31,62,63}, -- crown/base of small round foliage
  },planter_spray=false,
  prop_ground={[30]=5,[31]=5,[62]=5,[63]=5},
  when_above={[76]={{above={60,75,76,77},class='wall'}}}}
end
local johto=common()
johto.pins.planter={46,47} -- tall tree's middle course, drawn as foliage
johto.prop_ground[46]=5;johto.prop_ground[47]=5
johto.when_below={
  [30]={{below={46},class='planter'}}, -- crown continues into tall tree body
  [31]={{below={47},class='planter'}},
}
return {tilesets={TILESET_JOHTO=johto,TILESET_JOHTO_MODERN=common()}}
