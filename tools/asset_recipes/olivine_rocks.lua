-- Complete repeating boulder in Olivine Gym. An editable low dome replaces
-- the detector's square boxes; its top and flank sample their source bands.
local a={id='olivine_gym_boulder',tiles={{70,71},{86,87}},
 surfaces={{rect={0,0,1,1},orientation='vertical',height=0,depth=1}},
 voxelEdits={{x=0,y=0,z=0,remove=true}}}
for y=0,12 do for x=0,15 do for z=0,15 do
 local dx,dz=(x-7.5)/7.7,(z-7.5)/7.7
 -- Slightly uneven shoulders keep the rounded rocks from looking machined.
 local h=13-.5*dx+.4*dz
 if dx*dx+dz*dz+(y/h)^2<=1 then
  local sy
  if y/h>=math.abs(dz)*.8 then sy=math.floor(z/2)
  else sy=8+math.min(7,math.floor((1-y/h)*7)) end
  a.voxelEdits[#a.voxelEdits+1]={x=x,y=y,z=z,i=sy*16+x,region=1}
 end
end end end
return {tilesets={TILESET_CHAMPIONS_ROOM={assets={a}}}}
