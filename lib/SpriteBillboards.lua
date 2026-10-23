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
local poses=setmetatable({},{__mode='k'})
local generation=0
-- Snapshot once per rendered scene; color, ghost and shadow passes share it.
function SpriteBillboards.beginFrame()generation=generation+1 end
function SpriteBillboards.anchor(def,x,z)
 if def.id=='SPRITE_BIG_SNORLAX'or def.id=='SPRITE_BIG_LAPRAS'then return x+8,z+16 end
 return x,z
end

-- One flat quad UV-mapped to the complete native frame. A hair of inset keeps
-- the sampler inside this frame rather than picking up the neighbouring
-- one along the shared edge.
local function buildCard(def, frame, geometry, image)
  local ok, img = true,image
  if not img then ok,img=pcall(Assets.image,def.image)end
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
  local fw,fh=def.frameWidth or 16,def.frameHeight or 16
  local ax,ay=def.anchorX or fw/2,def.anchorY or fh
  local cols,offset=def.frameColumns or 1,def.frameOffset or 0
  local index=frame+offset
  local sx,sy=(index%cols)*fw,math.floor(index/cols)*fh
  local sw,sh=fw,fh
  if geometry then
    fw,fh=geometry.width or fw,geometry.height or fh
    ax,ay=geometry.anchorX or ax,geometry.anchorY or ay
    sx,sy=geometry.x or 0,geometry.y or 0
    sw,sh=fw,fh
    -- The engine's quad also covers grid sheets and frame offsets. Its
    -- viewport is authoritative when older geometry x/y fields lag behind.
    if geometry.quad then sx,sy,sw,sh=geometry.quad:getViewport()end
  end
  if sx+sw>iw or sy+sh>ih then sx,sy=0,0 end
  local u0,u1=(sx+.02)/iw,(sx+sw-.02)/iw
  local v0,v1=(sy+.05)/ih,(sy+sh-.05)/ih
  local dw,dh=def.displayWidth or fw,def.displayHeight or fh
  local dax,day=def.displayAnchorX or ax*dw/fw,def.displayAnchorY or ay*dh/fh
  local bottom=0
  -- Preserve the established native static-prop grounding. Explicit
  -- variable anchors belong to their author and need no pixel scan.
  if not geometry and fw==16 and fh==16 and ax==8 and ay==16 and def.frames==1 then
    local got,data=pcall(Assets.imageData,def.image)
    if got and data then
      for y=15,0,-1 do
        local ink=false
        for x=0,15 do
          local r,_,_,a=data:getPixel(sx+x,sy+y)
          if a>0 and(def.trueColor or r<=.83)then ink=true;break end
        end
        if ink then bottom=15-y;break end
      end
    end
  end
  local x0,y0=8-dax,day-dh-bottom
  local verts={
    {x0,y0,0,u0,v1,1},{x0+dw,y0,0,u1,v1,1},
    {x0+dw,y0+dh,0,u1,v0,1},{x0,y0+dh,0,u0,v0,1},
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
function SpriteBillboards.mesh(def,frame,geometry,image)
  local key=tostring(def.image)..'#'..frame
  local sx,sy,sw,sh
  if geometry then
    sx,sy,sw,sh=geometry.x or 0,geometry.y or 0,geometry.width,geometry.height
    if geometry.quad then sx,sy,sw,sh=geometry.quad:getViewport()end
  end
  -- Include all geometry in the key: two defs may share an image but use
  -- different frame sizes, grid offsets, anchors or world display scales.
  local legacy=not geometry and(def.frameWidth or 16)==16 and(def.frameHeight or 16)==16
    and(def.anchorX or 8)==8 and(def.anchorY or 16)==16
    and(def.frameColumns or 1)==1 and(def.frameOffset or 0)==0
    and not def.displayWidth and not def.displayHeight and not def.displayAnchorX and not def.displayAnchorY
  if def.id=='SPRITE_BIG_SNORLAX'or def.id=='SPRITE_BIG_LAPRAS'then key=key..':big'end
  if not legacy then key=key..':'..table.concat({sx or -1,sy or -1,sw or -1,sh or -1,
    geometry and geometry.width or def.frameWidth or 16,
    geometry and geometry.height or def.frameHeight or 16,
    geometry and geometry.anchorX or def.anchorX or -1,
    geometry and geometry.anchorY or def.anchorY or -1,
    def.frameColumns or 1,def.frameOffset or 0,
    def.displayWidth or -1,def.displayHeight or -1,
    def.displayAnchorX or -1,def.displayAnchorY or -1},':')end
  if meshes[key]==nil then
    local ok,m=pcall(buildCard,def,frame,geometry,image)
    meshes[key]=(ok and m)or false
  end
  return meshes[key]or nil
end

local SR
local function nativePose(sprite,facing,phase,flip)
  local def=sprite.def
  local frame,mirror=0,false
  if(def.frames or 1)>1 then
    frame=(def.walker and phase==1)and SR.WALK[facing]or SR.STAND[facing]
    frame=frame or 0
    if frame>=(def.frames or 1)then frame=0 end
    mirror=facing=='right'or((facing=='down'or facing=='up')and phase==1 and flip)or false
  end
  return frame,mirror
end
local directions={down=0,up=1,left=2,right=3}
function SpriteBillboards.pose(sprite,facing,phase,flip)
  SR=SR or require('src.render.SpriteRenderer')
  local key=(directions[facing]or 0)*4+(phase==1 and 2 or 0)+(flip and 1 or 0)
  local bucket=poses[sprite]
  if not bucket then bucket={};poses[sprite]=bucket end
  local entry=bucket[key]
  local def=sprite.def
  local native=sprite.getPoseGeometry==SR.getPoseGeometry and sprite.getFrameGeometry==SR.getFrameGeometry
    and(def.frameWidth or 16)==16 and(def.frameHeight or 16)==16
    and(def.anchorX or 8)==8 and(def.anchorY or 16)==16
    and(def.frameColumns or 1)==1 and(def.frameOffset or 0)==0
    and not def.displayWidth and not def.displayHeight
    and not def.displayAnchorX and not def.displayAnchorY
  if entry and entry.def==sprite.def and entry.image==sprite.image
    and(entry.generation==generation or(native and entry.native))then
    return entry.mesh,entry.mirror,entry.frame
  end
  local frame,mirror,geometry
  if not native and type(sprite.getPoseGeometry)=='function'and def.id~='SPRITE_BIG_SNORLAX'and def.id~='SPRITE_BIG_LAPRAS'then
    geometry=sprite:getPoseGeometry(facing,phase,flip)
    frame,mirror=geometry.frame,geometry.mirror
  else frame,mirror=nativePose(sprite,facing,phase,flip)end
  local mesh=SpriteBillboards.mesh(def,frame,geometry,sprite.image)
  entry=entry or{};bucket[key]=entry
  entry.generation,entry.def,entry.image=generation,def,sprite.image
  entry.mesh,entry.mirror,entry.frame,entry.native=mesh,mirror,frame,native
  return mesh,mirror,frame
end

-- Kept as its own name because the shadow and ghost passes read as their
-- own thing at the call sites; it once carried a different mesh from the
-- solid draw, and now deliberately does not.
SpriteBillboards.shadowQuad = SpriteBillboards.mesh

function SpriteBillboards.invalidate()
  meshes = {}
  poses=setmetatable({},{__mode='k'})
end

Assets.register(SpriteBillboards.invalidate)

return SpriteBillboards
