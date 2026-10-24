local runtime=debug.getinfo(1,'S').source:sub(2):match('(.+)/tests/')
local repo=runtime..'/../new_mod_ex'
local profile=dofile(repo..'/../../../archive/voxel-profile-before-native-polish-1.0.9.lua')
local Surface=dofile(repo..'/lib/AssetSurface.lua')
local recipe=dofile(repo..'/tools/asset_recipes/small_tree_cleanup.lua')
local targets={johto_small_tree=true,modern_small_tree=true,forest_sapling=true,
 forest_cut_tree=true,kanto_sapling=true}
local function components(m)
 local seen,out={},{}
 local function k(x,y,z)return x..':'..y..':'..z end
 local ds={{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1}}
 for _,c in ipairs(m.cells)do if not seen[k(c.x,c.y,c.z)]then
  local q={c};seen[k(c.x,c.y,c.z)]=true;local n=1
  while q[n]do local u=q[n];n=n+1
   for _,d in ipairs(ds)do local x,y,z=u.x+d[1],u.y+d[2],u.z+d[3];local id=k(x,y,z)
    if not seen[id]and m.at(x,y,z)~=nil then seen[id]=true;q[#q+1]={x=x,y=y,z=z}end
   end
  end
  out[#out+1]=#q
 end end
 table.sort(out,function(a,b)return a>b end);return out
end
local function model(a)return Surface.build(#a.tiles[1]*8,#a.tiles*8,a.surfaces,a.voxelEdits)end
local function snapshot(edits) edits=edits or {}
 local out={};for i,e in ipairs(edits or {})do local p={};for k,v in pairs(e)do p[k]=v end;out[i]=p end;return out
end
local function equal(a,b)
 assert(#a==#b,'edits changed on repeated application')
 for i,e in ipairs(a)do for k,v in pairs(e)do assert(b[i][k]==v,'edit changed on repeated application')end
  for k in pairs(b[i])do assert(e[k]~=nil,'edit field changed on repeated application')end
 end
end
local assets={}
for _,list in pairs(profile.buildings)do for _,a in ipairs(list)do if targets[a.id]then assets[a.id]=a end end end
for id in pairs(targets)do assert(assets[id],'missing authored tree '..id)end
local totals={removed=0,added=0}
for _,id in ipairs({'johto_small_tree','modern_small_tree','forest_sapling','forest_cut_tree','kanto_sapling'})do
 local a=assets[id];local before=model(a);local baseline=components(before)
 assert(#baseline>1,id..' should begin disconnected')
 local height=before.ytop;local xmin,xmax=before.xmin,before.xmax
 local oldCount=#before.cells;local oldEditCount=#(a.voxelEdits or {})
 assert(recipe(a),id..' was not targeted')
 local after=model(a);local cc=components(after)
 assert(#cc==1,id..' remains disconnected: '..table.concat(cc,','))
 assert(after.ymin==0 and after.ytop==height,id..' changed vertical extent')
 assert(after.xmin==xmin and after.xmax==xmax,id..' changed source silhouette footprint')
 local removed,added=0,0
 for i=oldEditCount+1,#a.voxelEdits do local e=a.voxelEdits[i];if e.remove then removed=removed+1 elseif e.i then added=added+1 end end
 assert(removed<=100 and added<=8,id..' cleanup too large: -'..removed..' +'..added)
 assert(#after.cells<=oldCount+8 and #after.cells>=oldCount-100,id..' changed too many voxels')
 if id=='forest_cut_tree'then
  local trunk,canopy=0,0;for _,c in ipairs(after.cells)do if c.y<=3 then trunk=trunk+1 elseif c.y>=4 and c.y<=15 then canopy=canopy+1 end end
  assert(trunk==136 and canopy>=970 and canopy<=978,'cut tree grounded trunk/canopy changed: '..trunk..'/'..canopy)
 end
 totals.removed=totals.removed+removed;totals.added=totals.added+added
 local edits=snapshot(a.voxelEdits);recipe(a);equal(edits,a.voxelEdits)
end
local other
for _,list in pairs(profile.buildings)do for _,a in ipairs(list)do if not targets[a.id]then other=a;break end end;if other then break end end
local beforeOther=snapshot(other.voxelEdits)
assert(not recipe(other),'unrelated asset was targeted');equal(beforeOther,other.voxelEdits)
print(('Small tree cleanup: 5 assets connected; removed %d voxels, added %d bridge voxels; idempotence and unrelated asset PASS'):format(totals.removed,totals.added))
