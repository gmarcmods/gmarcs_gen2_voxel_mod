-- Voxel world mode: characters as flat forward-facing sprite billboards.
--
-- Every character -- the player, NPCs, the ghosts standing on a neighbour
-- map -- is its CURRENT 2D sprite frame on a single flat quad. The sheets
-- carry real alpha and the shader discards it, so the quad cuts the
-- sprite's exact silhouette out of itself; no geometry is built from the
-- pixels and nothing about a sprite is voxelized.
--
-- That is deliberate. A sprite is a DRAWING, not an object seen from one
-- side: Gen 1's overworld figures are 16x16 icons with a fixed front-on
-- reading, and turning one into a solid -- whether a contoured slab or a
-- carved visual hull -- reconstructs a body the artist never drew and the
-- game never implied. It also had the mod ship a description of the ROM
-- art. One quad wearing the real frame is both more faithful and cheaper:
-- Static props also inspect their bottom transparent margin once, so their
-- visible feet rest on their support rather than hovering above it.
--
-- The card always faces SOUTH -- the direction the 2D game implies -- and
-- only LEANS BACK, pivoting at its feet, by exactly the camera's pitch
-- (VoxelScene's billboardMatrix), so at every tilt level it reads face-on
-- like the flat game. Right-facing and the alternating walk step are
-- matrix mirrors, not extra meshes. UVs point into the live sheet image,
-- so RED++ OBP bakes, SGB palette bakes and sprite-replacing mods all
-- texture it with no rebuild.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local Assets = require("src.render.Assets")
local Voxel3D = V.require("Voxel3D")

local SpriteBillboards = {}

local meshes = {}
function SpriteBillboards.anchor(def,x,z)
 if def.id=='SPRITE_BIG_SNORLAX'or def.id=='SPRITE_BIG_LAPRAS'then return x+8,z+16 end
 return x,z
end

-- One flat 16x16 quad UV-mapped to a whole frame. A hair of inset keeps
-- the sampler inside this frame rather than picking up the neighbouring
-- one along the shared edge.
local function buildCard(def, frame)
  local ok, img = pcall(Assets.image, def.image)
  if not (ok and img) then return nil end
  local iw, ih = img:getDimensions()
  if def.id=='SPRITE_BIG_SNORLAX'or def.id=='SPRITE_BIG_LAPRAS'then
    -- Native FacingBigDollSymmetric: two stacked 16px source frames,
    -- mirrored into a complete 32px square. These are not walking poses.
    local verts,indices={},{}
    for half=0,1 do for side=0,1 do
      local x,y=side*16-8,(1-half)*16
      local u0,u1=.02/iw,15.98/iw
      if side==1 then u0,u1=u1,u0 end
      local v0,v1=(half*16+.05)/ih,(half*16+15.95)/ih
      local n=#verts
      for _,p in ipairs({{x,y,0,u0,v1,1},{x+16,y,0,u1,v1,1},
        {x+16,y+16,0,u1,v0,1},{x,y+16,0,u0,v0,1}})do verts[#verts+1]=p end
      Voxel3D.pushQuad(indices,n/4)
    end end
    return Voxel3D.newMesh(verts,indices)
  end
  local fy = frame * 16
  if fy + 16 > ih then fy = 0 end
  local u0, u1 = 0.02 / iw, (16 - 0.02) / iw
  local v0, v1 = (fy + 0.05) / ih, (fy + 15.95) / ih
  local bottom = 0
  if def.frames == 1 then
    local got, data = pcall(Assets.imageData, def.image)
    if got and data then
      for y = 15, 0, -1 do
        local ink = false
        for x = 0, 15 do
          local r, _, _, a = data:getPixel(x, fy + y)
          if a > 0 and (def.trueColor or r <= 0.83) then ink = true; break end
        end
        if ink then bottom = 15 - y; break end
      end
    end
  end
  local verts = {
    { 0, -bottom, 0, u0, v1, 1 }, { 16, -bottom, 0, u1, v1, 1 },
    { 16, 16-bottom, 0, u1, v0, 1 }, { 0, 16-bottom, 0, u0, v0, 1 },
  }
  local indices = {}
  Voxel3D.pushQuad(indices, 0)
  return Voxel3D.newMesh(verts, indices)
end

-- The card for one (sprite def, frame index), or nil (headless / no
-- image), cached like every other derived GPU object.
--
-- The solid draw, the sun pass and the player's occlusion silhouette all
-- take THIS mesh. That the three agree is load-bearing, not tidiness: the
-- silhouette is drawn with the depth test INVERTED, so any self-overlap in
-- the mesh would read as "behind something" and repaint the figure on open
-- ground whether or not anything hides it; and the sun must see the same
-- outline the camera does, or a shadow stops matching what casts it.
function SpriteBillboards.mesh(def, frame)
  local key = def.image .. "#" .. frame
  if meshes[key] == nil then
    local ok, m = pcall(buildCard, def, frame)
    meshes[key] = (ok and m) or false
  end
  return meshes[key] or nil
end

-- Kept as its own name because the shadow and ghost passes read as their
-- own thing at the call sites; it once carried a different mesh from the
-- solid draw, and now deliberately does not.
SpriteBillboards.shadowQuad = SpriteBillboards.mesh

function SpriteBillboards.invalidate()
  meshes = {}
end

Assets.register(SpriteBillboards.invalidate)

return SpriteBillboards
