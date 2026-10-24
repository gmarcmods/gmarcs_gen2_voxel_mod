local root=arg[1]or'mods/gen2/new_mod_ex'
local repair=assert(loadfile(root..'/tools/asset_recipes/pagoda_roof_materials.lua'))()
local p=dofile(root..'/../../../archive/voxel-profile-before-native-polish-1.0.9.lua');local count=0
for _,a in ipairs(p.buildings.TILESET_JOHTO)do
 if a.id=='johto_sprout_tower'or a.id=='johto_burned_tower'or a.id=='johto_tin_tower'then
  local old={};for i,e in ipairs(a.voxelEdits)do old[i]={x=e.x,y=e.y,z=e.z,i=e.i,remove=e.remove,region=e.region}end
  assert(repair(a));count=count+1
  local changes=0;local W=#a.tiles[1]*8
  for i,e in ipairs(a.voxelEdits)do
   local b=old[i];assert(e.x==b.x and e.y==b.y and e.z==b.z and e.remove==b.remove and e.region==b.region,'roof geometry changed')
   if e.i~=b.i then
    changes=changes+1;assert(e.y%28>=24 and e.y<(a.id=='johto_tin_tower'and 252 or 84),'non-roof texel changed')
    local row=math.floor(e.i/W)%8;assert(row==0 or row==1,'white eave texel repeated across roof')
   end
  end
  assert(changes>100,'roof repair must do useful work')
  local previous={};for i,e in ipairs(a.voxelEdits)do previous[i]=e.i end
  repair(a);for i,e in ipairs(a.voxelEdits)do assert(e.i==previous[i],'material repair is not idempotent')end
 end
end
assert(count==3);assert(not repair({id='johto_house',voxelEdits={}}))
print('PAGODA ROOF MATERIALS PASS')
