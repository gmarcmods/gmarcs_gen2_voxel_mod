-- Connected two-pixel crown courses shaped from the native front silhouette.
-- Ground-shadow pixels are not extruded into a root ball. All colours remain
-- references into the selected sprite; no generated textures or random noise.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
local masks=dofile(dir..'/native_tree_masks.lua')
local donors=dofile(dir..'/tree_texel_donors.lua')
local targets={johto_tree=20,modern_tree=20,forest_tree=28,park_tree=28}
local function largest(row)
 local lo,hi,best=0,0,0
 for s,e in row:gmatch('()#+()')do if e-s>best then lo,hi,best=s-1,e-2,e-s end end
 return lo,hi
end
return function(a)
 local D=targets[a.id];if not D then return false end
 local spec=masks[a.id];local W,H=#a.tiles[1]*8,#a.tiles*8
 local cx,cz=(W-1)/2,(H-1)/2
 local edits={{x=0,y=0,z=0,remove=true}}
 local function donor(sx,sy,pool)
  local pick,score
  for _,i in ipairs(pool)do
   local x,y=i%W,math.floor(i/W);local d=(x-sx)^2+(y-sy)^2*2
   if not score or d<score then pick,score=i,d end
  end
  return pick
 end
 local function block(x,y,z,height,i)
  for dy=0,height-1 do for dx=0,1 do for dz=0,1 do
   edits[#edits+1]={x=x+dx,y=y+dy,z=z+dz,i=i,region=1}
  end end end
 end
 for sy=0,spec.leafRows-1,2 do
  local lo,hi=largest(spec.mask[sy+1]);local l,h=largest(spec.mask[math.min(sy+2,spec.leafRows)])
  local rx=math.max(2,(math.max(hi,h)-math.min(lo,l)+1)/2)
  local rz=math.max(2,D/2*rx/(W/2))
  local height=math.min(2,spec.leafRows-sy)
  for x=0,W-2,2 do for z=0,H-2,2 do
   local dx,dz=x+.5-cx,z+.5-cz
   if (dx/rx)^2+(dz/rz)^2<=1 then
    local sx=x
    if math.abs(dx/rx)>math.abs(dz/rz)then sx=cx+dz/rz*(rx-1)end
    local i=donor(math.floor(sx/2)*2,sy,donors[a.id].leaf)
    block(x,H-sy-height,z,height,i)
   end
  end end
 end
 local trunk=H-spec.leafRows
 local radius=W==16 and 2 or 3
 for y=0,trunk-1 do for x=0,W-2,2 do for z=0,H-2,2 do
  local r=y<2 and radius+1 or radius
  if (x+.5-cx)^2+(z+.5-cz)^2<=r*r then
   block(x,y,z,1,donor(cx+(x+.5-cx),H-1-y,donors[a.id].wood))
  end
 end end end
 a.surfaces={{rect={0,0,1,1},orientation='vertical',height=0,depth=1,z=0}}
 a.voxelEdits=edits
 return true
end
