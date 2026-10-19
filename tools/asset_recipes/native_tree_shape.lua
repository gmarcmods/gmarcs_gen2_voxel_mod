-- Reconstruct editable solid foliage from each native sprite's silhouette.
local dir=debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.'
local masks=dofile(dir..'/native_tree_masks.lua')
local clean=dofile(dir..'/clean_tree_shape.lua')
return function(a)
 if clean(a)then return a end
 local spec=assert(masks[a.id],'unknown native tree '..a.id)
 local W,H=#a.tiles[1]*8,#a.tiles*8
 local D=spec.depth;local cz=(D-1)/2
 a.surfaces={{rect={0,0,1,1},orientation='vertical',height=0,depth=1,z=0}}
 a.voxelEdits={{x=0,y=0,z=0,remove=true}}
 for sy,row in ipairs(spec.mask)do
  local lo,hi=row:find('#'),nil
  for x=W,1,-1 do if row:sub(x,x)=='#'then hi=x;break end end
  if lo then
   lo,hi=lo-1,hi-1
   local cx,rx=(lo+hi)/2,(hi-lo+1)/2
   local crown=sy<=spec.leafRows
   local rz=crown and D/2*(rx/(W/2)) or math.min(D/4,rx)
   for x=lo,hi do if row:sub(x+1,x+1)=='#'then
    local chord=rz*math.sqrt(math.max(0,1-((x-cx)/(rx+.01))^2))
    for z=math.max(0,math.ceil(cz-chord)),math.min(D-1,math.floor(cz+chord))do
     -- Side faces project the same native row across depth, avoiding a
     -- black-outline stripe around the entire flank of a revolved tree.
     local sx=x
     if math.abs((x-cx)/rx)>math.abs((z-cz)/math.max(rz,.01))then
      sx=math.max(lo,math.min(hi,math.floor(cx+(z-cz)/math.max(rz,.01)*(rx-.5)+.5)))
      if row:sub(sx+1,sx+1)~='#'then sx=x end
     end
     local i=(sy-1)*W+sx
     -- A crown cap is foliage, not the sprite's black silhouette outline.
     -- Retain the native row on its front/back; use inner leaf texels on
     -- exposed interior steps so the canopy cannot become a black lid.
     if a.id=='forest_tree' and crown and z>math.ceil(cz-chord) and z<math.floor(cz+chord)then
      i=(6+(x+2*z)%14)*W+8+(x+z)%16
     end
     a.voxelEdits[#a.voxelEdits+1]={x=x,y=H-sy,z=z,i=i,region=1}
    end
   end end
  end
 end
 return a
end
