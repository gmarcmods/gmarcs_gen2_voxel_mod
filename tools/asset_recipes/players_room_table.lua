-- Player's Room gold table: the complete 32x24 map drawing, including the
-- lower row omitted by the older table class pins. Source pixels stay 1:1.
-- The map repeats the middle atlas column, so matching the atlas rectangle
-- directly would never place this asset.
local asset={id='players_room_table',tiles={{16,17,17,18},{32,33,33,34},{48,49,49,50}},
  surfaces={
    -- Rows 0..15 show the tabletop from above.
    {rect={0,0,32,16},orientation='horizontal',depth=1,height=6,z=0},
    -- Rows 16..17 form the two-pixel apron under the lid.
    {rect={0,16,32,2},orientation='vertical',depth=16,height=4,z=0},
    -- Only the drawn front legs, excluding the floor between them.
    {rect={1,18,5,4},orientation='vertical',depth=2,height=0,z=14},
    {rect={26,18,5,4},orientation='vertical',depth=2,height=0,z=14},
  },voxelEdits={}}
-- The bottom row of each foot tapers inward. The discarded corner pixels
-- belong to the floor. Continue the same legs at the rear of the tabletop,
-- using the front-leg texels, as the original furniture extrusion does.
for region,start in ipairs({1,26}) do
  for x=start,start+4 do for y=0,3 do
    local footCorner=y==0 and (x==start or x==start+4)
    for z=0,1 do
      if footCorner then
        asset.voxelEdits[#asset.voxelEdits+1]={x=x,y=y,z=z+14,remove=true}
      else
        asset.voxelEdits[#asset.voxelEdits+1]={x=x,y=y,z=z,i=(21-y)*32+x,region=region+2}
      end
    end
  end end
end
return asset
