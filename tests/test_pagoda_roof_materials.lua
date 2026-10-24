local root=arg[1]or'mods/gen2/new_mod_ex'
local repair=assert(loadfile(root..'/tools/asset_recipes/pagoda_roof_materials.lua'))()
local Surface=dofile(root..'/lib/AssetSurface.lua')
local p=dofile(root..'/../../../archive/voxel-profile-before-native-polish-1.0.9.lua')
local levels={johto_sprout_tower=3,johto_burned_tower=3,johto_tin_tower=9}
local count,totalChanges=0,0
local function model(a)
 return Surface.build(#a.tiles[1]*8,#a.tiles*8,a.surfaces,a.voxelEdits)
end
for _,a in ipairs(p.buildings.TILESET_JOHTO)do
 local n=levels[a.id]
 if n then
  count=count+1
  local before=model(a);local W=#a.tiles[1]*8
  local layers={}
  for _,v in ipairs(before.cells)do layers[v.y]=(layers[v.y]or 0)+1 end
  local roofs={};for y,cells in pairs(layers)do if cells>=W*8 then roofs[y]=true end end
  local expected=2*n;local found=0
  for _ in pairs(roofs)do found=found+1 end
  assert(found==expected,a.id..': expected '..expected..' broad roof layers, found '..found)
  local oldEdits={};for i,e in ipairs(a.voxelEdits)do
   oldEdits[i]={x=e.x,y=e.y,z=e.z,i=e.i,remove=e.remove,region=e.region}
  end
  assert(repair(a));local after=model(a)
  assert(#before.cells==#after.cells,a.id..': voxel geometry count changed')
  local changedByLayer={};local changes=0
  for _,v in ipairs(before.cells)do
   local value=after.at(v.x,v.y,v.z)
   assert(value~=nil,a.id..': repair removed a voxel')
   if value~=v.i then
    changes=changes+1
    assert(roofs[v.y],a.id..': changed non-roof texel at y='..v.y)
    changedByLayer[v.y]=(changedByLayer[v.y]or 0)+1
    local sy=math.floor(value/W);local sx=value%W
    local tile=a.tiles[math.floor(sy/8)+1][math.floor(sx/8)+1]
    local row=sy%8
    assert(tile==82 and(row==0 or row==1),a.id..': changed material is not native tile 82 row 0/1')
   end
  end
  for y in pairs(roofs)do assert((changedByLayer[y]or 0)>0,a.id..': roof layer y='..y..' unchanged')end
  for i,e in ipairs(a.voxelEdits)do
   local b=oldEdits[i]
   assert(b and e.x==b.x and e.y==b.y and e.z==b.z and e.remove==b.remove and e.region==b.region,
    a.id..': roof repair changed geometry')
   if e.i~=b.i then
    local sy=math.floor(e.i/W);local sx=e.i%W
    local tile=a.tiles[math.floor(sy/8)+1][math.floor(sx/8)+1]
    assert(tile==82 and(sy%8==0 or sy%8==1),a.id..': edited source is not tile 82 row 0/1')
   end
  end
  assert(changes>100,a.id..': roof repair must do useful work ('..changes..')')
  totalChanges=totalChanges+changes
  local previous={};for i,e in ipairs(a.voxelEdits)do previous[i]=e.i end
  repair(a);for i,e in ipairs(a.voxelEdits)do assert(e.i==previous[i],a.id..': material repair is not idempotent')end
 end
end
assert(count==3);assert(not repair({id='johto_house',voxelEdits={}}))
print(('PAGODA ROOF MATERIALS PASS (%d changed roof texels)'):format(totalChanges))
