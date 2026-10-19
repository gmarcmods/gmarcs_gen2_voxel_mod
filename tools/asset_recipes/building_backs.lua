-- Reuse the building's own wall and foundation tiles on its closed rear.
-- Preserve every sculpted coordinate and the complete front/roof artwork.
return function(a,roofRows)
 local W,H=#a.tiles[1]*8,#a.tiles*8
 local positions={}
 for row,tiles in ipairs(a.tiles) do for col,tile in ipairs(tiles) do
  if not positions[tile] then positions[tile]={x=(col-1)*8,y=(row-1)*8} end
 end end
 local wall=positions[7] and 7 or positions[27] and 27
 if not wall then return 0 end
 local count=0
 for _,v in ipairs(a.voxelEdits or {}) do
  if not v.remove and v.z==0 and v.y>=0 and v.y<H-roofRows then
   local tile=wall
   if v.x==0 and positions[26] then tile=26
   elseif v.x==W-1 and positions[28] then tile=28 end
   if v.y<8 then
    local base=v.x==0 and 1 or v.x==W-1 and 22 or 2
    if positions[base] then tile=base end
   end
   local p=positions[tile]
   local i=(p.y+7-v.y%8)*W+p.x+v.x%8
   if v.i~=i then v.i=i;count=count+1 end
  end
 end
 return count
end
