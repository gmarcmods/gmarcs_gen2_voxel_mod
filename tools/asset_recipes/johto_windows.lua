-- The window tile has two bright panes within a one-pixel frame.
-- Recess the panes, preserve their source texels, and project the sill.
return function(a,front)
 local W,H=#a.tiles[1]*8,#a.tiles*8
 local function edit(x,y,z,i,remove)
  a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=i,remove=remove,region=1}
 end
 for r,row in ipairs(a.tiles) do for c,tile in ipairs(row) do if tile==38 then
  local x0,sy0=(c-1)*8,(r-1)*8
  for py=1,6 do for _,px in ipairs({1,2,5,6}) do
   local x,y=x0+px,H-1-sy0-py;local i=(sy0+py)*W+x
   edit(x,y,front,nil,true);edit(x,y,front-1,i)
  end end
  for px=0,7 do
   local x=x0+px;edit(x,H-1-sy0-7,front+1,(sy0+7)*W+x)
  end
 end end end
end
