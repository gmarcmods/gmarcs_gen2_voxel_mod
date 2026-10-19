-- Authored against TILESET_CAVE's actual map arrangements.
local rock={id='cave_boulder',tiles={{12,13},{28,29}},surfaces={},voxelEdits={}}
-- Each source row becomes a horizontal band of the rock. Narrow crown
-- and base leave the surrounding floor out of the solid silhouette.
for sy=0,13 do
 local inset=sy==0 and 6 or sy==1 and 4 or sy==2 and 2 or sy==13 and 4 or sy==12 and 2 or 1
 local width=16-2*inset
 rock.surfaces[#rock.surfaces+1]={rect={inset,sy,width,1},orientation='vertical',height=13-sy,depth=width,z=inset-1}
 for x=inset,15-inset do for z=inset-1,14-inset do
  if (x-7.5)^2+(z-6.5)^2>(width/2)^2 then
   rock.voxelEdits[#rock.voxelEdits+1]={x=x,y=13-sy,z=z,remove=true}
  end
 end end
end
return {tilesets={TILESET_CAVE={
 terrain_edges=dofile((debug.getinfo(1,'S').source:sub(2):match('(.+)/')or'.')..'/low_cave_edges.lua').tilesets.TILESET_CAVE.terrain_edges,
 classes={cave_plateau={base='wall',height=16,art='flat'}},
 pins={
  ground={1}, -- speckled traversable cave floor
  cave_plateau={22}, -- dense rock fill above the enclosing cliff course
  wall={10,11,21,23,37,38,39}, -- corners and continuous exposed rock rim
  water={20}, -- cave pools stay recessed below the walking floor
 },assets={rock},
}}}
